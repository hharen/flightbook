require "net/http"
require "uri"
require "nokogiri"
require "cgi"
require "json"
require "zlib"
require "stringio"
require "openssl"
require "set"

class FlyingSessionsController < ApplicationController
  before_action :set_flying_session, only: %i[show edit update destroy]

  # GET /flying_sessions
  def index
    if params[:user_id].present?
      @selected_user = User.find(params[:user_id])
    else
      # Preselect user 'Hana' by default
      @selected_user = User.find_by(name: "Hana")
    end

    if @selected_user
      @flying_sessions = FlyingSession.where(user: @selected_user).includes(:user, :instructor)
      @total_flight_time = @flying_sessions.total_flight_time
    else
      @flying_sessions = FlyingSession.all.includes(:user, :instructor)
    end
    @users = User.all
  end

  # GET /flying_sessions/1
  def show
  end

  # GET /flying_sessions/new
  def new
    @flying_session = FlyingSession.new
    @users = User.all
    @instructors = Instructor.all
  end

  # GET /flying_sessions/1/edit
  def edit
    @users = User.all
    @instructors = Instructor.all
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
      # First, authenticate and get the cookie
      cookie = authenticate_and_get_cookie

      if cookie.blank?
        redirect_to flying_sessions_path, alert: "Failed to authenticate with Windwerk. Please check your credentials."
        return
      end

      # Make the request to Windwerk with the obtained cookie
      html_content = fetch_windwerk_data(cookie)

      if html_content.present?
        created_count = parse_and_create_sessions(html_content)
        message = "Successfully imported #{created_count} flying sessions from Windwerk."
        redirect_to flying_sessions_path, notice: message
      else
        redirect_to flying_sessions_path, alert: "Failed to fetch data from Windwerk after authentication."
      end
    rescue => e
      Rails.logger.error "Error fetching Windwerk data: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to flying_sessions_path, alert: "An error occurred while fetching data: #{e.message}"
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_flying_session
      if params[:user_id].present?
        @selected_user = User.find(params[:user_id])
        @flying_session = @selected_user.flying_sessions.find(params[:id])
      else
        @flying_session = FlyingSession.find(params[:id])
      end
    end

    # Only allow a list of trusted parameters through.
    def flying_session_params
      params.require(:flying_session).permit(:date, :time, :date_time, :note, :user_id, :instructor_id, :duration)
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

        # Log all sessions found and create session records (without flights)
        Rails.logger.info "=== ALL SESSIONS FOUND ==="
        session_links.each_with_index do |link, index|
          session_text = link.text.strip
          filter_value = link["href"]&.match(/filter_value=(\d+)/)&.[](1)

          Rails.logger.info "Session #{index + 1}: #{session_text}"
          Rails.logger.info "Filter value: #{filter_value}" if filter_value
          Rails.logger.info "Full href: #{link['href']}" if link["href"]

          # Use Unix timestamp from filter_value for accurate date/time parsing
          if filter_value
            begin
              # Convert Unix timestamp to DateTime
              timestamp = filter_value.to_i
              date_time = Time.at(timestamp).to_datetime

              Rails.logger.info "✅ Parsed from timestamp: #{date_time}"

              # Create the flying session using the precise timestamp (without flights)
              session_data = create_session_from_timestamp(timestamp)
              if session_data
                created_count += 1
                Rails.logger.info "✅ Created flying session record (flights will be added only for current session)"
              else
                Rails.logger.warn "❌ Failed to create session"
              end
            rescue => e
              Rails.logger.error "❌ Error parsing timestamp #{filter_value}: #{e.message}"

              # Fallback to text parsing if timestamp fails
              Rails.logger.info "🔄 Falling back to text parsing"
              if match = session_text.match(/(\d{1,2}\s+\w+\.?\s+\d{4})\s+bis\s+(\d{1,2}:\d{2})/)
                date_str = match[1]
                time_str = match[2]
                Rails.logger.info "✅ Fallback parsed: #{date_str} at #{time_str}"

                session_data = create_session_from_date_time(date_str, time_str)
                if session_data
                  created_count += 1
                  Rails.logger.info "✅ Created flying session record (fallback, flights will be added only for current session)"
                end
              end
            end
          else
            Rails.logger.warn "❌ No filter_value found in href"
          end

          Rails.logger.info "---"
        end

        # After creating all session records, add flights only to the current session
        Rails.logger.info "=== ADDING FLIGHTS TO CURRENT SESSION ==="

        # Look for the current session button to identify which session has video data
        current_button = doc.css("button").find { |btn| btn.text.include?("Flugsession") }
        current_session = nil

        if current_button
          strong_element = current_button.css("strong").first
          if strong_element
            current_text = strong_element.text.strip
            Rails.logger.info "Current session from button: #{current_text}"

            if match = current_text.match(/(\d{1,2}\s+\w+\.?\s+\d{4})\s+bis\s+(\d{1,2}:\d{2})/)
              date_str = match[1]
              time_str = match[2]
              Rails.logger.info "✅ Parsed current: #{date_str} at #{time_str}"

              # First try to find existing session
              current_session = find_session_from_date_time(date_str, time_str)
              if current_session
                Rails.logger.info "✅ Found existing current session for flight extraction: #{current_session.id}"
              else
                Rails.logger.info "Current session not found in dropdown, creating it"
                # Create the current session since it's not in the dropdown
                current_session = create_session_from_date_time(date_str, time_str)
                if current_session
                  created_count += 1
                  Rails.logger.info "✅ Created current session for flight extraction: #{current_session.id}"
                else
                  Rails.logger.warn "❌ Failed to create current session"
                end
              end
            end
          end
        end

        # Add flights only to the current session
        if current_session
          flights_created = extract_and_create_flights(html_content, current_session)
          Rails.logger.info "✅ Added #{flights_created} flights to current session #{current_session.id} (#{current_session.date_time})"
        else
          Rails.logger.info "⚠️ No current session found for flight extraction"
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

    def extract_and_create_flights(html_content, flying_session)
      return 0 unless flying_session

      doc = Nokogiri::HTML(html_content)
      created_flights = 0

      Rails.logger.info "=== EXTRACTING FLIGHTS FOR SESSION #{flying_session.id} ==="

      # Look for media containers that have video information
      media_containers = doc.css(".media_container_responsive")
      Rails.logger.info "Found #{media_containers.length} media containers"

      # Extract flight numbers from the HTML structure
      flight_numbers = Set.new

      media_containers.each do |container|
        # Look for flight number in the filename attribute or in bold tags
        flight_number = extract_flight_number_from_container(container)

        if flight_number
          flight_numbers.add(flight_number)
          Rails.logger.info "Found flight ##{flight_number}"
        end
      end

      Rails.logger.info "Unique flight numbers found: #{flight_numbers.to_a.sort}"

      # Create one flight per unique flight number
      flight_numbers.each do |flight_number|
        # Create empty flight (duration and note will be set manually later)
        flight = flying_session.flights.create!(number: flight_number)

        created_flights += 1
        Rails.logger.info "✅ Created flight for ##{flight_number}"
      end

      Rails.logger.info "=== CREATED #{created_flights} FLIGHTS FOR SESSION ==="
      created_flights
    end

    def extract_flight_number_from_container(container)
      flight_number = nil

      # Look for flight number in data-filename attribute (e.g., "#1_20251103_171034_Top.mp4")
      filename_input = container.css("input.media-select[data-filename]").first
      if filename_input
        filename = filename_input["data-filename"]
        if filename && match = filename.match(/#(\d+)_/)
          flight_number = match[1].to_i
        end
      end

      flight_number
    end

    def update_sessions_without_flights(html_content)
      # This is called automatically during session creation
      # Find a few recent sessions that don't have flights
      sessions_without_flights = FlyingSession.left_joins(:flights)
                                            .where(flights: { id: nil })
                                            .order(date_time: :desc)

      sessions_without_flights.each do |session|
        Rails.logger.info "Auto-updating session #{session.id} (#{session.date_time})"
        flights_created = extract_and_create_flights(html_content, session)
        Rails.logger.info "✅ Added #{flights_created} flights to existing session" if flights_created > 0
      end
    end


    def create_session_from_timestamp(timestamp)
      # Convert Unix timestamp to DateTime in the correct timezone
      begin
        # Unix timestamps from Windwerk are in UTC but should be interpreted in Swiss time
        utc_time = Time.at(timestamp.to_i).utc
        swiss_time = utc_time.in_time_zone("Europe/Zurich")
        date_time = swiss_time

        Rails.logger.info "Creating session from timestamp #{timestamp} -> #{date_time} (Swiss time)"

        # Find the user named Hana
        user = User.find_by(name: "Hana")
        return nil unless user

        # Check if this session already exists for the user
        existing_session = user.flying_sessions.find_by(date_time: date_time)
        if existing_session
          Rails.logger.info "Flying session already exists for #{date_time}"
          return existing_session
        end

        # Create new flying session
        flying_session = user.flying_sessions.create!(
          date_time: date_time
        )

        Rails.logger.info "Created flying session: #{flying_session.id} for #{date_time}"
        flying_session

      rescue => e
        Rails.logger.error "Error creating session from timestamp '#{timestamp}': #{e.message}"
        nil
      end
    end

    def find_session_from_date_time(date_str, time_str)
      # Parse German date format "30 Okt. 2025" to find existing session
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

        # Combine date and time and handle timezone
        # The timestamps from Windwerk are in CET/CEST, so we need to match that
        target_date_time = Time.zone.local(date.year, date.month, date.day, time.hour, time.min)

        Rails.logger.info "Looking for existing session with date_time: #{target_date_time} (in UTC: #{target_date_time.utc})"

        # Find the user named Hana
        user = User.find_by(name: "Hana")
        return nil unless user

        # Look for session within a reasonable time window (2 hours) to handle timezone differences
        start_time = target_date_time.utc - 2.hours
        end_time = target_date_time.utc + 2.hours

        existing_session = user.flying_sessions.where(date_time: start_time..end_time).first
        if existing_session
          Rails.logger.info "Found existing session: #{existing_session.id} at #{existing_session.date_time}"
          existing_session
        else
          Rails.logger.warn "No existing session found for #{target_date_time}"
          nil
        end

      rescue => e
        Rails.logger.error "Error finding session from date_time '#{date_str} #{time_str}': #{e.message}"
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

        # Combine date and time in Swiss timezone
        date_time = Time.zone.local(date.year, date.month, date.day, time.hour, time.min)

        Rails.logger.info "Parsed date_time: #{date_time} (Swiss time)"

        # Find the user named Hana
        user = User.find_by(name: "Hana")
        return nil unless user

        # Check if this session already exists for the user
        existing_session = user.flying_sessions.find_by(date_time: date_time)
        if existing_session
          Rails.logger.info "Flying session already exists for #{date_time}"
          return existing_session
        end

        # Create new flying session
        flying_session = user.flying_sessions.create!(
          date_time: date_time
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
      combined_text = [date_text, time_text].compact.join(" ")

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

      # Update the session's Total flight time
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

      0
    end

    def fetch_windwerk_data(cookie)
      uri = URI("https://media.windwerk.ch/proflyer")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      # Configure SSL to match curl's behavior
      # In development, we'll be more lenient with SSL verification
      if Rails.env.development?
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        Rails.logger.warn "SSL verification disabled for development"
      else
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:144.0) Gecko/20100101 Firefox/144.0"
      request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      request["Accept-Language"] = "en-US,en;q=0.5"
      request["Accept-Encoding"] = "gzip, deflate, br, zstd"
      request["Referer"] = "https://media.windwerk.ch/proflyer"
      request["Connection"] = "keep-alive"
      request["Cookie"] = cookie
      request["Upgrade-Insecure-Requests"] = "1"
      request["Sec-Fetch-Dest"] = "document"
      request["Sec-Fetch-Mode"] = "navigate"
      request["Sec-Fetch-Site"] = "same-origin"
      request["Sec-Fetch-User"] = "?1"
      request["Priority"] = "u=0, i"

      Rails.logger.info "Making GET request to Windwerk with provided cookie..."

      response = http.request(request)

      if response.code.to_i == 200
        Rails.logger.info "✅ Successfully fetched data from Windwerk"

        # Handle compressed response (matching --compressed flag)
        content = case response["content-encoding"]
        when "gzip"
          Zlib::GzipReader.new(StringIO.new(response.body)).read
        when "deflate"
          Zlib::Inflate.inflate(response.body)
        when "br"
          # Brotli decompression would need additional gem
          Rails.logger.warn "Brotli compression detected but not supported, using raw body"
          response.body
        else
          response.body
        end

        content
      else
        Rails.logger.error "❌ Failed to fetch data from Windwerk. Status: #{response.code}"
        Rails.logger.error "Response: #{response.body[0..500]}"
        nil
      end
    rescue => e
      Rails.logger.error "❌ Error making request to Windwerk: #{e.message}"
      raise e
    end

    def authenticate_and_get_cookie
      uri = URI("https://media.windwerk.ch/proflyer")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      # Configure SSL to match curl's behavior
      if Rails.env.development?
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        Rails.logger.warn "SSL verification disabled for development"
      else
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end

      request = Net::HTTP::Post.new(uri)
      request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:144.0) Gecko/20100101 Firefox/144.0"
      request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
      request["Accept-Language"] = "en-US,en;q=0.5"
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request["Origin"] = "https://media.windwerk.ch"
      request["Connection"] = "keep-alive"
      request["Referer"] = "https://media.windwerk.ch/proflyer"
      request["Upgrade-Insecure-Requests"] = "1"
      request["Sec-Fetch-Dest"] = "document"
      request["Sec-Fetch-Mode"] = "navigate"
      request["Sec-Fetch-Site"] = "same-origin"
      request["Sec-Fetch-User"] = "?1"
      request["Priority"] = "u=0, i"

      # Get credentials from Rails secrets
      email = Rails.application.credentials.email
      password = Rails.application.credentials.password

      if email.blank? || password.blank?
        Rails.logger.error "❌ Windwerk email or password not found in Rails secrets"
        raise "Windwerk credentials not configured"
      end

      # Set the POST body data
      request.body = "ctrl=do&do=login&goto=proflyer&login=#{CGI.escape(email)}&password=#{CGI.escape(password)}"

      Rails.logger.info "Making POST authentication request to Windwerk..."

      response = http.request(request)

      if response.code.to_i == 200 || response.code.to_i == 302
        Rails.logger.info "✅ Authentication request completed with status: #{response.code}"

        # Extract cookie from Set-Cookie headers
        cookies = response.get_fields("Set-Cookie")
        if cookies&.any?
          # Combine all cookies into a single string
          cookie_string = cookies.map { |cookie| cookie.split(";").first }.join("; ")
          Rails.logger.info "✅ Successfully obtained authentication cookie"

          # Handle redirect (302) - make follow-up GET request
          if response.code.to_i == 302
            Rails.logger.info "🔄 Handling redirect, making follow-up GET request..."

            # Make the follow-up GET request with the obtained cookie
            get_request = Net::HTTP::Get.new(uri)
            get_request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:144.0) Gecko/20100101 Firefox/144.0"
            get_request["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
            get_request["Accept-Language"] = "en-US,en;q=0.5"
            get_request["Accept-Encoding"] = "gzip, deflate, br, zstd"
            get_request["Referer"] = "https://media.windwerk.ch/proflyer"
            get_request["Connection"] = "keep-alive"
            get_request["Cookie"] = cookie_string
            get_request["Upgrade-Insecure-Requests"] = "1"
            get_request["Sec-Fetch-Dest"] = "document"
            get_request["Sec-Fetch-Mode"] = "navigate"
            get_request["Sec-Fetch-Site"] = "same-origin"
            get_request["Sec-Fetch-User"] = "?1"
            get_request["Priority"] = "u=0, i"

            get_response = http.request(get_request)

            if get_response.code.to_i == 200
              Rails.logger.info "✅ Follow-up GET request successful"

              # Check if there are additional cookies from the GET response
              additional_cookies = get_response.get_fields("Set-Cookie")
              if additional_cookies&.any?
                # Merge additional cookies with existing ones
                additional_cookie_string = additional_cookies.map { |cookie| cookie.split(";").first }.join("; ")
                cookie_string = "#{cookie_string}; #{additional_cookie_string}"
                Rails.logger.info "✅ Updated cookie string with additional cookies from GET response"
              end
            else
              Rails.logger.warn "⚠️ Follow-up GET request returned status: #{get_response.code}"
            end
          end

          cookie_string
        else
          Rails.logger.error "❌ No cookies found in authentication response"
          nil
        end
      else
        Rails.logger.error "❌ Authentication failed. Status: #{response.code}"
        Rails.logger.error "Response: #{response.body[0..500]}"
        nil
      end
    rescue => e
      Rails.logger.error "❌ Error during authentication: #{e.message}"
      raise e
    end
end
