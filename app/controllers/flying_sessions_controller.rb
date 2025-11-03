require "net/http"
require "uri"
require "nokogiri"
require "cgi"
require "json"

class FlyingSessionsController < ApplicationController
  before_action :set_flying_session, only: %i[ show edit update destroy ]

  # Hardcoded cookie for Windwerk booking authentication
  WINDWERK_COOKIE = "_ga_40169XR08J=GS2.1.s1762122873$o30$g1$t1762129633$j34$l0$h1247841990; _ga=GA1.1.1415058565.1745671404; FPID=FPID2.2.4dN%2BuJt91Qtb6dyWEMY2Vyp2DUyOkdc1Z4OOpPm8sdc%3D.1745671404; _fbp=fb.1.1745671404377.1426736015; _clck=ozawaf%5E2%5Eg0p%5E0%5E1942; _hjSessionUser_1319343=eyJpZCI6ImNlY2I1YTUyLTU4ZGItNTY4NC1hN2FhLTcwOGY3NjU0NGRhYyIsImNyZWF0ZWQiOjE3NDU2NzE0MDQ3ODUsImV4aXN0aW5nIjp0cnVlfQ==; _tt_enable_cookie=1; _ttp=01JSS1ZF7W8ECYR1D3BHP9GQHP_.tt.1; ttcsid_CS525IJC77UBU0VRRH2G=1762122874231::LtQKY0hf0u7tIIg6XL…F7iGDPWdYN8OhsEd0jrkqRkZ%2FO9BdC%2B%2BXyiRHBkdLTieQ6EoxVdc%2BEqtLMKMz9MIL84IKl8b6hXVxd%2BHcIkrWsW8%2BfrE65U%2F1M8ISGmts3NSlnK8DO1SNg%3D%3D; FPAU=1.1.1743238882.1762104226; _clsk=1eg3qzf%5E1762129628691%5E88%5E1%5Ea.clarity.ms%2Fcollect; Tunn3lShop=m5vh2r5n7kl9eard8p5v870kuf; _hjSession_1319343=eyJpZCI6IjVmM2ZhOWRkLTY1Y2YtNDRhNy05OTFjLTAwMmY0N2U4MDQzMCIsImMiOjE3NjIxMjY2NjQyNTcsInMiOjAsInIiOjAsInNiIjowLCJzciI6MCwic2UiOjAsImZzIjowLCJzcCI6MX0=; FPGSID=1.1762128924.1762129607.G-40169XR08J.fftVA-y2CudTnIewOYdN4g".freeze

  # Hardcoded cookie for Windwerk media authentication
  WINDWERK_MEDIA_COOKIE = "_ga_40169XR08J=GS2.1.s1762122873$o30$g1$t1762129893$j39$l0$h1247841990; _ga=GA1.1.1415058565.1745671404; FPID=FPID2.2.4dN%2BuJt91Qtb6dyWEMY2Vyp2DUyOkdc1Z4OOpPm8sdc%3D.1745671404; _fbp=fb.1.1745671404377.1426736015; _clck=ozawaf%5E2%5Eg0p%5E0%5E1942; _hjSessionUser_1319343=eyJpZCI6ImNlY2I1YTUyLTU4ZGItNTY4NC1hN2FhLTcwOGY3NjU0NGRhYyIsImNyZWF0ZWQiOjE3NDU2NzE0MDQ3ODUsImV4aXN0aW5nIjp0cnVlfQ==; _tt_enable_cookie=1; _ttp=01JSS1ZF7W8ECYR1D3BHP9GQHP_.tt.1; ttcsid_CS525IJC77UBU0VRRH2G=1762122874231::LtQKY0hf0u7tIIg6XLV7.25.1762129893903.0; ttcsid=1762122874231::m7oD2Gr4R6gQW4exCXBO.26.1762129893903.0; Tunn3lMedia=p8d6hee5md3oknkftved9e43e7; _pin_unauth=dWlkPVlUTXpaRGhsTlRRdFpHTTVZUzAwTURBekxUZzJNR1V0TkdVMllqY3dOR1JsWTJOaA; _icl_visitor_lang_js=en_us; _gcl_au=1.1.1743238882.1762104226.311283892.1762124867.1762129874; FPLC=WghAjrQn%2F7iGDPWdYN8OhsEd0jrkqRkZ%2FO9BdC%2B%2BXyiRHBkdLTieQ6EoxVdc%2BEqtLMKMz9MIL84IKl8b6hXVxd%2BHcIkrWsW8%2BfrE65U%2F1M8ISGmts3NSlnK8DO1SNg%3D%3D; FPAU=1.1.1743238882.1762104226; _clsk=1eg3qzf%5E1762129893675%5E94%5E1%5Ea.clarity.ms%2Fcollect; _pin_unauth=dWlkPVlUTXpaRGhsTlRRdFpHTTVZUzAwTURBekxUZzJNR1V0TkdVMllqY3dOR1JsWTJOaA; _hjSession_1319343=eyJpZCI6IjVmM2ZhOWRkLTY1Y2YtNDRhNy05OTFjLTAwMmY0N2U4MDQzMCIsImMiOjE3NjIxMjY2NjQyNTcsInMiOjAsInIiOjAsInNiIjowLCJzciI6MCwic2UiOjAsImZzIjowLCJzcCI6MX0=; FPGSID=1.1762128924.1762129873.G-40169XR08J.fftVA-y2CudTnIewOYdN4g".freeze

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
      # Step 1: Login directly to media.windwerk.ch
      login_response = login_with_hardcoded_cookie

      # Check if login was successful
      raise "Log in didn't succeed" unless login_successful?(login_response)

      # Step 2: After successful login, fetch media proflyer page with media cookie
      sessions_response = fetch_flying_sessions_with_cookie(WINDWERK_MEDIA_COOKIE)

      # puts "-----RESPONSE: #{sessions_response.body}"
      # Step 3: Parse the HTML response and create flying sessions with flights
      created_sessions = parse_and_create_sessions(sessions_response.body)

      success_message = "Flying sessions data fetched successfully! Login: #{login_response.code}, Sessions: #{sessions_response.code}. Created #{created_sessions} sessions."
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

    def login_with_hardcoded_cookie
      uri = URI("https://booking.windwerk.ch/index.php")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri)
      request["Accept"] = "application/json, text/javascript, */*; q=0.01"
      request["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
      request["Origin"] = "https://booking.windwerk.ch"
      request["Connection"] = "keep-alive"
      request["Cookie"] = WINDWERK_COOKIE

      # Get credentials from Rails credentials
      email = Rails.application.credentials.email
      password = Rails.application.credentials.password

      raise "Email not configured in credentials" unless email
      raise "Password not configured in credentials" unless password

      request.body = "ctrl=do&do=checkout_connect_user&email=#{CGI.escape(email)}&password=#{CGI.escape(password)}&token="
      response = http.request(request)

      # Check login success and log result
      if login_successful?(response)
        Rails.logger.info "✅ LOGIN SUCCESSFUL - Authentication completed"
      else
        Rails.logger.error "❌ LOGIN FAILED - Authentication failed"
      end

      response
    end

    def login_successful?(login_response)
      # Check if the response is JSON with status "valid"
      begin
        json_response = JSON.parse(login_response.body)
        if json_response["status"] == "valid"
          Rails.logger.info "Login successful - JSON response with status: valid"
          Rails.logger.info "User ID: #{json_response['user_id']}" if json_response["user_id"]
          true
        else
          Rails.logger.warn "Login failed - JSON response status: #{json_response['status']}"
          false
        end
      rescue JSON::ParserError
        Rails.logger.warn "Login failed - response is not valid JSON"
        Rails.logger.info "Response body: #{login_response.body}"
        false
      end
    end

    def follow_login_redirect(login_response)
      # After successful login, follow the redirect to /proflyer on the same domain
      redirect_location = login_response["location"]
      Rails.logger.info "Following redirect to: #{redirect_location}"

      # Construct the full URL for the redirect
      uri = URI("https://booking.windwerk.ch#{redirect_location}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Get.new(uri)
      request["Origin"] = "https://booking.windwerk.ch"
      request["Connection"] = "keep-alive"
      # Use the same cookies that worked for login
      request["Cookie"] = WINDWERK_COOKIE

      response = http.request(request)
      Rails.logger.info "Redirect follow response: #{response.code}"
      Rails.logger.info "Response body preview: #{response.body[0..500]}..." if response.body

      # If this redirects us again or we need to go to media.windwerk.ch, handle that
      if response.code.start_with?("3") && response["location"]
        Rails.logger.info "Got another redirect to: #{response['location']}"
        # If it redirects to media.windwerk.ch, follow that
        if response["location"].include?("media.windwerk.ch")
          return fetch_flying_sessions_with_cookie(WINDWERK_COOKIE)
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

      response = http.request(request)
      Rails.logger.info "Flying sessions fetch response: #{response.code}"
      puts "-----RESPONSE BODY: #{response.body}"

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
