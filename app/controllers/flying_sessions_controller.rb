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
      login_response = login_to_media
      Rails.logger.info "Login response: #{login_response.code}"
puts "-----------------_________#{login_response.body}"
      # Step 2: Follow redirect after successful login
      final_response = follow_login_redirect(login_response)
      Rails.logger.info "Final response: #{final_response.code}"

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

    def login_to_media
      # Login directly to media.windwerk.ch/proflyer
      uri = URI("https://media.windwerk.ch/proflyer")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request["Accept"] = "application/json, text/javascript, */*; q=0.01"
      request["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
      request["Origin"] = "https://media.windwerk.ch"
      request["Connection"] = "keep-alive"
      request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:143.0) Gecko/20100101 Firefox/143.0"

      # Get credentials from Rails credentials
      email = Rails.application.credentials.email
      password = Rails.application.credentials.password

      raise "Email not configured in credentials" unless email
      raise "Password not configured in credentials" unless password

      # Login directly to proflyer page
      request.body = "ctrl=do&do=login&login=#{CGI.escape(email)}&password=#{CGI.escape(password)}"

      Rails.logger.info "=== LOGIN DIRECTLY TO PROFLYER ==="
      Rails.logger.info "URL: #{uri}"
      Rails.logger.info "Body: #{request.body}"

      response = http.request(request)

      Rails.logger.info "Login response code: #{response.code}"
      Rails.logger.info "Login response headers: #{response.to_hash}"
      Rails.logger.info "Response body preview: #{response.body[0..500]}..." if response.body

      response
    end

    def follow_login_redirect(login_response)
      current_response = login_response
      cookies = extract_cookies_from_response(login_response)
      max_redirects = 5  # Prevent infinite redirect loops
      redirect_count = 0

      Rails.logger.info "=== REDIRECT HANDLING ==="
      Rails.logger.info "Initial response code: #{current_response.code}"
      Rails.logger.info "Initial cookies: #{cookies}"

      # Follow redirects until we get a non-redirect response or reach max redirects
      while current_response.code.start_with?("3") && current_response["location"] && redirect_count < max_redirects
        redirect_count += 1
        redirect_location = current_response["location"]

        Rails.logger.info "=== REDIRECT #{redirect_count} ==="
        Rails.logger.info "Redirecting to: #{redirect_location}"

        # Handle relative vs absolute URLs
        if redirect_location.start_with?("http")
          uri = URI(redirect_location)
        else
          # Relative redirect - construct full URL based on media domain
          if redirect_location.start_with?("/")
            # Use the media domain for absolute paths since we're starting there
            uri = URI("https://media.windwerk.ch#{redirect_location}")
          else
            # Relative path - this is uncommon but handle it
            base_uri = URI("https://media.windwerk.ch/")
            uri = base_uri + redirect_location
          end
        end

        Rails.logger.info "Final redirect URI: #{uri}"
        Rails.logger.info "Domain: #{uri.host}"

        # Make the redirect request
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(uri)
        request["Origin"] = "https://#{uri.host}"
        request["Connection"] = "keep-alive"
        request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:143.0) Gecko/20100101 Firefox/143.0"

        # Use cookies from login and any set by previous redirects
        request["Cookie"] = cookies if cookies.present?

        current_response = http.request(request)

        Rails.logger.info "Redirect response code: #{current_response.code}"
        Rails.logger.info "Response headers: #{current_response.to_hash.select { |k, v| k.downcase.include?('location') || k.downcase.include?('cookie') }}"

        # Update cookies with any new ones from this response
        new_cookies = extract_cookies_from_response(current_response)
        cookies = merge_cookies(cookies, new_cookies) if new_cookies.present?

        # Log what we got
        if current_response.body&.include?("Flugsession")
          Rails.logger.info "✅ Found 'Flugsession' in response - reached target page!"
          break
        elsif current_response.body&.include?("Forgotten or need to create password?")
          Rails.logger.error "❌ Got login page - authentication failed"
          break
        end
      end

      if redirect_count >= max_redirects
        Rails.logger.error "❌ Too many redirects (#{redirect_count}) - stopping"
      end

      # If we don't have 'Flugsession' in the final response, try redirecting to /proflyer
      if !current_response.body&.include?("Flugsession") && !current_response.body&.include?("Forgotten or need to create password?")
        Rails.logger.info "=== MANUAL REDIRECT TO PROFLYER ==="
        Rails.logger.info "Final response doesn't contain 'Flugsession', redirecting to /proflyer"

        # Make manual GET request to /proflyer with the cookies we have
        uri = URI("https://media.windwerk.ch/proflyer")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Get.new(uri)
        request["Origin"] = "https://media.windwerk.ch"
        request["Connection"] = "keep-alive"
        request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:143.0) Gecko/20100101 Firefox/143.0"
        request["Cookie"] = cookies if cookies.present?

        proflyer_response = http.request(request)

        Rails.logger.info "Proflyer redirect response code: #{proflyer_response.code}"
        Rails.logger.info "Proflyer response contains 'Flugsession': #{proflyer_response.body&.include?('Flugsession')}"

        # Use the proflyer response if it's better than what we had
        if proflyer_response.body&.include?("Download selected")
          Rails.logger.info "✅ Successfully got proflyer page with flight data!"
          current_response = proflyer_response
        end
      end

      Rails.logger.info "=== FINAL RESPONSE ==="
      Rails.logger.info "Final response code: #{current_response.code}"
      Rails.logger.info "Final cookies: #{cookies}"
      Rails.logger.info "Body contains 'Flugsession': #{current_response.body&.include?('Flugsession')}"

      current_response
    end

    def extract_cookies_from_response(response)
      # Extract Set-Cookie headers and convert to Cookie format
      set_cookies = response.get_fields("Set-Cookie") || []
      return nil if set_cookies.empty?

      # Convert Set-Cookie to Cookie format (name=value pairs only)
      cookie_pairs = set_cookies.map do |cookie|
        cookie.split(";").first  # Take only the name=value part, ignore attributes
      end

      cookie_pairs.join("; ")
    end

    def merge_cookies(existing_cookies, new_cookies)
      return new_cookies if existing_cookies.blank?
      return existing_cookies if new_cookies.blank?

      # Simple merge - new cookies override existing ones with same name
      existing_pairs = existing_cookies.split("; ").map { |pair| pair.split("=", 2) }.to_h
      new_pairs = new_cookies.split("; ").map { |pair| pair.split("=", 2) }.to_h

      merged = existing_pairs.merge(new_pairs)
      merged.map { |name, value| "#{name}=#{value}" }.join("; ")
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
