require "net/http"
require "uri"
require "nokogiri"
require "cgi"
require "json"
require "zlib"
require "stringio"
require "openssl"

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
    cookie = params[:cookie]

    if cookie.blank?
      redirect_to flying_sessions_path, alert: "Cookie is required to fetch flight data."
      return
    end

    begin
      # Make the request to Windwerk with the provided cookie
      html_content = fetch_windwerk_data(cookie)

      if html_content.present?
        created_count = parse_and_create_sessions(html_content)
        redirect_to flying_sessions_path, notice: "Successfully imported #{created_count} flying sessions from Windwerk."
      else
        redirect_to flying_sessions_path, alert: "Failed to fetch data from Windwerk. Please check your cookie and try again."
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
        @flying_session = @selected_user.flying_sessions.find(params.expect(:id))
      else
        @flying_session = FlyingSession.find(params.expect(:id))
      end
    end

    # Only allow a list of trusted parameters through.
    def flying_session_params
      params.expect(flying_session: [ :date, :time, :date_time, :flight_time, :note, :user_id, :instructor_id ])
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
end
