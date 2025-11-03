require "net/http"
require "uri"
require "nokogiri"
require "cgi"
require "json"

class FlyingSessionsController < ApplicationController
  before_action :set_flying_session, only: %i[ show edit update destroy ]

  # GET /flying_sessions
  def index
    if params[:user_id].present?
      @selected_user = User.find(params[:user_id])
      @flying_sessions = FlyingSession.where(user: @selected_user).includes(:user, :instructor)
    else
      @flying_sessions = FlyingSession.all.includes(:user, :instructor)
    end
    @users = User.all.order(:name)
  end

  # GET /flying_sessions/1
  def show
  end

  # GET /flying_sessions/new
  def new
    @flying_session = FlyingSession.new
  end

  # GET /flying_sessions/1/edit
  def edit
  end

  # POST /flying_sessions
  def create
    @flying_session = FlyingSession.new(flying_session_params.except(:date, :time))

    # Combine date and time into date_time if they exist
    if params.dig(:flying_session, :date).present? && params.dig(:flying_session, :time).present?
      date_str = params[:flying_session][:date]
      time_str = params[:flying_session][:time]
      @flying_session.date_time = DateTime.parse("#{date_str} #{time_str}")
    end

    if @flying_session.save
      redirect_to @flying_session, notice: "Flying session was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end  # PATCH/PUT /flying_sessions/1
  def update
    # Combine date and time into date_time if they exist
    if params.dig(:flying_session, :date).present? && params.dig(:flying_session, :time).present?
      date_str = params[:flying_session][:date]
      time_str = params[:flying_session][:time]
      @flying_session.date_time = DateTime.parse("#{date_str} #{time_str}")
    end

    if @flying_session.update(flying_session_params.except(:date, :time))
      redirect_to @flying_session, notice: "Flying session was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /flying_sessions/1
  def destroy
    @flying_session.destroy!
    redirect_to flying_sessions_path, notice: "Flying session was successfully destroyed.", status: :see_other
  end

  # POST /flying_sessions/get_flying_sessions
  def get_flying_sessions
    begin
      # Step 1: Login to booking.windwerk.ch
      login_response = login_with_hardcoded_cookie
      
      # Check if login was successful
      raise "Login didn't succeed" unless login_successful?(login_response)
      
      # Step 2: Follow any redirects manually to get to the flight data
      final_response = follow_redirects_manually(login_response)
      
      # Step 3: Parse the HTML response and create flying sessions
      created_sessions = parse_and_create_sessions(final_response.body)

      success_message = "Flying sessions data fetched successfully! Login: #{login_response.code}, Final: #{final_response.code}. Created #{created_sessions} sessions."
      redirect_to flying_sessions_path, notice: success_message

    rescue => e
      Rails.logger.error "Error fetching flying sessions: #{e.message}"
      redirect_to flying_sessions_path, alert: "Failed to fetch flying sessions: #{e.message}"
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_flying_session
      if params[:user_id].present?
        @selected_user = User.find(params[:user_id])
        @flying_session = @selected_user.flying_sessions.find(params.expect(:id))
      else
        @flying_session = FlyingSession.find(params.expect(:id))
      end
    end

    # Only allow a list of trusted parameters through.
    def flying_session_params
      params.expect(flying_session: [ :date, :time, :date_time, :flight_time, :note, :user_id, :instructor_id ])
    end

    def login
      uri = URI("https://media.windwerk.ch/proflyer")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request["Accept"] = "application/json, text/javascript, */*; q=0.01"
      request["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
      request["Origin"] = "https://booking.windwerk.ch"
      request["Connection"] = "keep-alive"
      request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:143.0) Gecko/20100101 Firefox/143.0"


      #       curl 'https://booking.windwerk.ch/index.php' \
      # --compressed \
      # -X POST \
      # -H 'Accept: application/json, text/javascript, */*; q=0.01' \
      # -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
      # -H 'Origin: https://booking.windwerk.ch' \
      # -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:143.0) Gecko/20100101 Firefox/143.0' \
      # -H 'Connection: keep-alive' \
      # --data-raw 'ctrl=do&do=checkout_connect_user&email=h.harencarova%40gmail.com&password=woodpaper498WW_&token=' \
      # -v


      # Get credentials from Rails credentials
      email = Rails.application.credentials.email
      password = Rails.application.credentials.password

      raise "Email not configured in credentials" unless email
      raise "Password not configured in credentials" unless password

      request.body = "ctrl=do&do=checkout_connect_user&email=#{CGI.escape(email)}&password=#{CGI.escape(password)}&token="
      response = http.request(request)

      response
    end

    def follow_redirects_manually(login_response)
      current_response = login_response
      redirect_count = 0
      max_redirects = 5
      cookies = WINDWERK_COOKIE
      
      Rails.logger.info "=== MANUAL REDIRECT HANDLING ==="
      
      while redirect_count < max_redirects
        Rails.logger.info "Redirect #{redirect_count}: Response code #{current_response.code}"
        
        # Check if this is a redirect response (3xx status codes)
        if current_response.code.start_with?("3") && current_response["location"]
          redirect_count += 1
          redirect_location = current_response["location"]
          
          Rails.logger.info "Following redirect #{redirect_count} to: #{redirect_location}"
          
          # Handle relative vs absolute URLs
          if redirect_location.start_with?("http")
            # Absolute URL
            uri = URI(redirect_location)
          else
            # Relative URL - construct full URL
            if redirect_location.start_with?("/")
              # Absolute path
              uri = URI("https://booking.windwerk.ch#{redirect_location}")
            else
              # Relative path
              uri = URI("https://booking.windwerk.ch/#{redirect_location}")
            end
          end
          
          Rails.logger.info "Requesting: #{uri}"
          
          # Determine which cookies to use based on domain
          if uri.host == "media.windwerk.ch"
            cookies = WINDWERK_MEDIA_COOKIE
            Rails.logger.info "Switched to media.windwerk.ch - using WINDWERK_MEDIA_COOKIE"
          elsif uri.host == "booking.windwerk.ch"
            cookies = WINDWERK_COOKIE
            Rails.logger.info "Using booking.windwerk.ch - using WINDWERK_COOKIE"
          end
          
          # Make the redirect request
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          
          request = Net::HTTP::Get.new(uri)
          request["Origin"] = "https://#{uri.host}"
          request["Connection"] = "keep-alive"
          request["Cookie"] = cookies
          request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:143.0) Gecko/20100101 Firefox/143.0"
          
          current_response = http.request(request)
          Rails.logger.info "Redirect response: #{current_response.code}"
          
          # Update cookies if new ones are set
          if current_response["Set-Cookie"]
            new_cookies = current_response["Set-Cookie"]
            Rails.logger.info "Received new cookies: #{new_cookies[0..100]}..."
            # You might want to update the cookie for subsequent requests
          end
          
        else
          # Not a redirect, we're done
          Rails.logger.info "✅ Final destination reached with status: #{current_response.code}"
          break
        end
      end
      
      if redirect_count >= max_redirects
        Rails.logger.error "❌ Too many redirects (#{redirect_count}), stopping"
        raise "Too many redirects"
      end
      
      Rails.logger.info "=== REDIRECT HANDLING COMPLETE ==="
      current_response
        end
      end

      response
    end

    def fetch_flying_sessions_with_cookie(cookie)
      uri = URI("https://media.windwerk.ch/proflyer")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      request["Origin"] = "https://media.windwerk.ch"
      request["Connection"] = "keep-alive"
      request["Cookie"] = cookie
      request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:143.0) Gecko/20100101 Firefox/143.0"

      response = http.request(request)
      Rails.logger.info "Flying sessions fetch response: #{response.code}"

      # Check for login failure indicators
      if response.body&.include?("Forgotten or need to create password?")
        Rails.logger.error "❌ LOGIN/REDIRECT FAILED - Found 'Forgotten or need to create password?' text"
        Rails.logger.error "This indicates we're seeing a login page instead of the proflyer page"
        Rails.logger.error "Authentication may have failed or session expired"
        return response
      else
        Rails.logger.info "✅ we got to the media"
      end

      response
    end

    def parse_and_create_sessions(html_content)
      return 0 unless html_content.present?

      doc = Nokogiri::HTML(html_content)
      created_count = 0

      Rails.logger.info "=== PARSING HTML FOR FLIGHT SESSIONS ==="

      # Look specifically for the dropdown menu with flight sessions
      dropdown_menu = doc.css("ul.dropdown-menu").first

      if dropdown_menu
        Rails.logger.info "✅ Found dropdown menu!"

        # Get all the session links from the dropdown
        session_links = dropdown_menu.css("li a")
        Rails.logger.info "Found #{session_links.length} session links in dropdown"

        # Log all sessions found
        Rails.logger.info "=== ALL SESSIONS FOUND ==="
        session_links.each_with_index do |link, index|
          session_text = link.text.strip
          filter_value = link["href"]&.match(/filter_value=(\d+)/)&.[](1)

          Rails.logger.info "Session #{index + 1}: #{session_text}"
          Rails.logger.info "  Filter value: #{filter_value}" if filter_value
          Rails.logger.info "  Full href: #{link['href']}" if link["href"]

          # Use Unix timestamp from filter_value for accurate date/time parsing
          if filter_value
            begin
              # Convert Unix timestamp to DateTime
              timestamp = filter_value.to_i
              date_time = Time.at(timestamp).to_datetime

              Rails.logger.info "  ✅ Parsed from timestamp: #{date_time}"

              # Create the flying session using the precise timestamp
              session_data = create_session_from_timestamp(timestamp)
              if session_data
                created_count += 1
                Rails.logger.info "  ✅ Created flying session"
              else
                Rails.logger.warn "  ❌ Failed to create session"
              end
            rescue => e
              Rails.logger.error "  ❌ Error parsing timestamp #{filter_value}: #{e.message}"

              # Fallback to text parsing if timestamp fails
              Rails.logger.info "  🔄 Falling back to text parsing"
              if match = session_text.match(/(\d{1,2}\s+\w+\.?\s+\d{4})\s+bis\s+(\d{1,2}:\d{2})/)
                date_str = match[1]
                time_str = match[2]
                Rails.logger.info "  ✅ Fallback parsed: #{date_str} at #{time_str}"

                session_data = create_session_from_date_time(date_str, time_str)
                if session_data
                  created_count += 1
                  Rails.logger.info "  ✅ Created flying session (fallback)"
                end
              end
            end
          else
            Rails.logger.warn "  ❌ No filter_value found in href"
          end

          Rails.logger.info "---"
        end

        # Also check for current session in button (if any)
        current_button = doc.css("button").find { |btn| btn.text.include?("Flugsession") }
        if current_button
          Rails.logger.info "=== CURRENT SESSION FROM BUTTON ==="
          strong_element = current_button.css("strong").first
          if strong_element
            current_text = strong_element.text.strip
            Rails.logger.info "Current session: #{current_text}"

            if match = current_text.match(/(\d{1,2}\s+\w+\.?\s+\d{4})\s+bis\s+(\d{1,2}:\d{2})/)
              date_str = match[1]
              time_str = match[2]

              Rails.logger.info "✅ Parsed current: #{date_str} at #{time_str}"

              session_data = create_session_from_date_time(date_str, time_str)
              if session_data
                created_count += 1
                Rails.logger.info "✅ Created current flying session"
              end
            end
          end
        end

      else
        Rails.logger.warn "❌ Could not find ul.dropdown-menu in HTML"

        # Debug: Show what we actually have
        Rails.logger.info "=== DEBUG INFO ==="
        Rails.logger.info "HTML contains 'dropdown-menu': #{html_content.include?('dropdown-menu')}"
        Rails.logger.info "HTML contains 'Flugsession': #{html_content.include?('Flugsession')}"
        Rails.logger.info "HTML contains 'bis': #{html_content.include?('bis')}"

        # Show first 2000 characters of HTML for debugging
        Rails.logger.info "HTML preview (first 2000 chars):"
        Rails.logger.info html_content[0..2000]
      end

      Rails.logger.info "=== PARSING COMPLETE ==="
      Rails.logger.info "Total sessions created: #{created_count}"
      created_count
    end

    def create_session_from_timestamp(timestamp)
      # Convert Unix timestamp directly to DateTime
      begin
        date_time = Time.at(timestamp.to_i).to_datetime

        Rails.logger.info "Creating session from timestamp #{timestamp} -> #{date_time}"

        # Check if this session already exists for the current user
        existing_session = current_user.flying_sessions.find_by(date_time: date_time)
        if existing_session
          Rails.logger.info "Flying session already exists for #{date_time}"
          return existing_session
        end

        # Create new flying session
        flying_session = current_user.flying_sessions.create!(
          date_time: date_time,
          location: "Windwerk", # Default location
          notes: "Imported from Windwerk on #{Date.current}"
        )

        Rails.logger.info "Created flying session: #{flying_session.id} for #{date_time}"
        flying_session

      rescue => e
        Rails.logger.error "Error creating session from timestamp '#{timestamp}': #{e.message}"
        nil
      end
    end

    def create_session_from_date_time(date_str, time_str)
      # Parse German date format "30 Okt. 2025" to a proper date
      begin
        # Convert German month abbreviations to English
        german_months = {
          "Jan." => "Jan", "Feb." => "Feb", "März" => "Mar", "Apr." => "Apr",
          "Mai" => "May", "Juni" => "Jun", "Juli" => "Jul", "Aug." => "Aug",
          "Sept." => "Sep", "Okt." => "Oct", "Nov." => "Nov", "Dez." => "Dec"
        }

        # Replace German month with English equivalent
        english_date_str = date_str
        german_months.each do |german, english|
          english_date_str = english_date_str.gsub(german, english)
        end

        # Parse the date: "30 Oct 2025"
        date = Date.strptime(english_date_str, "%d %b %Y")

        # Parse the time: "18:00"
        time = Time.strptime(time_str, "%H:%M")

        # Combine date and time
        date_time = DateTime.new(date.year, date.month, date.day, time.hour, time.min)

        Rails.logger.info "Parsed date_time: #{date_time}"

        # Check if this session already exists for the current user
        existing_session = current_user.flying_sessions.find_by(date_time: date_time)
        if existing_session
          Rails.logger.info "Flying session already exists for #{date_time}"
          return existing_session
        end

        # Create new flying session
        flying_session = current_user.flying_sessions.create!(
          date_time: date_time,
          location: "Windwerk", # Default location
          notes: "Imported from Windwerk on #{Date.current}"
        )

        Rails.logger.info "Created flying session: #{flying_session.id} for #{date_time}"
        flying_session

      rescue => e
        Rails.logger.error "Error parsing date/time '#{date_str}' '#{time_str}': #{e.message}"
        nil
      end
    end

    def extract_session_data(session_element)
      # Extract date and time from the session element
      date_text = session_element.css('.date, .session-date, [class*="date"]').first&.text&.strip
      time_text = session_element.css('.time, .session-time, [class*="time"]').first&.text&.strip

      # Try to parse date and time
      date_time = parse_date_time(date_text, time_text)
      return nil unless date_time

      # Extract instructor information
      instructor_name = session_element.css('.instructor, .teacher, [class*="instructor"]').first&.text&.strip

      # Extract flights data
      flights = extract_flights_from_session(session_element)

      # Extract session notes
      notes = session_element.css('.notes, .comment, [class*="note"]').first&.text&.strip

      {
        date_time: date_time,
        instructor_name: instructor_name,
        flights: flights,
        notes: notes
      }
    end

    def parse_date_time(date_text, time_text)
      return nil unless date_text || time_text

      # Try different date/time formats
      combined_text = [ date_text, time_text ].compact.join(" ")

      # Common European date formats
      patterns = [
        "%d.%m.%Y %H:%M",
        "%d/%m/%Y %H:%M",
        "%Y-%m-%d %H:%M",
        "%d.%m.%Y",
        "%d/%m/%Y"
      ]

      patterns.each do |pattern|
        begin
          return DateTime.strptime(combined_text, pattern)
        rescue ArgumentError
          next
        end
      end

      # If no pattern works, try natural parsing
      begin
        DateTime.parse(combined_text)
      rescue ArgumentError
        Rails.logger.warn "Could not parse date/time: #{combined_text}"
        nil
      end
    end

    def extract_flights_from_session(session_element)
      flights = []

      # Look for flight duration and notes in various possible structures
      session_element.css('.flight, .duration, [class*="flight"], [class*="duration"]').each do |flight_element|
        duration_text = flight_element.text.strip

        # Extract duration in minutes from text like "15 min", "0:15", "15:00" etc.
        duration = parse_flight_duration(duration_text)

        if duration && duration > 0
          flight_note = flight_element.css(".note, .comment")&.first&.text&.strip
          flights << {
            duration: duration,
            note: flight_note
          }
        end
      end

      flights
    end

    def parse_flight_duration(duration_text)
      return nil unless duration_text.present?

      # Match patterns like "15 min", "0:15", "15:00", "15"
      if duration_text.match(/(\d+)\s*min/i)
        return $1.to_i
      elsif duration_text.match(/(\d+):(\d+)/)
        hours = $1.to_i
        minutes = $2.to_i
        return hours * 60 + minutes
      elsif duration_text.match(/^\d+$/)
        return duration_text.to_i
      end

      nil
    end

    def create_or_find_flying_session(session_data)
      user = User.find_by(name: "Hana")

      # Check if session already exists for this date/time
      existing_session = FlyingSession.find_by(
        date_time: session_data[:date_time]
      )

      return existing_session if existing_session

      # Create new session
      FlyingSession.create!(
        date_time: session_data[:date_time],
        user: user
      )
    end

    def find_or_create_instructor(instructor_name)
      return Instructor.first if instructor_name.blank?

      Instructor.find_or_create_by(name: instructor_name.strip)
    end

    def create_flights_for_session(flying_session, flights_data)
      created_count = 0
      total_duration = 0

      flights_data.each do |flight_data|
        Flight.create!(
          flying_session: flying_session,
          duration: flight_data[:duration],
          note: flight_data[:note]
        )

        total_duration += flight_data[:duration]
        created_count += 1
      end

      # Update the session's total flight time
      flying_session.update!(flight_time: total_duration)

      created_count
    end

    def parse_general_flight_data(doc)
      # Check if we're seeing a login form instead of flight data
      if doc.css('form input[name="login"], input[name="password"]').any?
        Rails.logger.warn "Received login form instead of flight data - login may have failed"
        Rails.logger.info "Login form found with title: #{doc.css('.voucher-check-title').text.strip}"
        raise "Login failed - received login form instead of flight data"
      end

      # Check if we have any flight-related content
      flight_indicators = [
        "flight", "session", "duration", "pilot", "instructor",
        "proflyer", "aufnahm", "flugsession"
      ]

      has_flight_content = flight_indicators.any? do |indicator|
        doc.text.downcase.include?(indicator)
      end

      unless has_flight_content
        Rails.logger.warn "No flight-related content found in response"
        Rails.logger.info "Page title: #{doc.css('title').text}"
        Rails.logger.info "Main content: #{doc.css('#main, .main, body').text.strip[0..200]}..."
        return 0
      end

      # Log the HTML structure to help with debugging
      Rails.logger.info "HTML structure for debugging:"
      Rails.logger.info "Title: #{doc.css('title').text}"
      Rails.logger.info "Main div classes: #{doc.css('div').map { |d| d['class'] }.compact.first(20)}"

      # Look for any table or list structures that might contain flight data
      tables = doc.css("table")
      if tables.any?
        Rails.logger.info "Found #{tables.count} tables - investigating content"
        tables.each_with_index do |table, i|
          Rails.logger.info "Table #{i}: #{table.text.strip[0..100]}..."
        end
      end

      # Look for divs that might contain session data
      content_divs = doc.css('div.content, div.session, div.flight, div[class*="session"], div[class*="flight"]')
      if content_divs.any?
        Rails.logger.info "Found potential content divs: #{content_divs.count}"
        content_divs.each_with_index do |div, i|
          Rails.logger.info "Content div #{i}: #{div.text.strip[0..100]}..."
        end
      end

      0
    end
end
