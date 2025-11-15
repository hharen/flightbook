require "test_helper"

class FlyingSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @flying_session = flying_sessions(:one)
  end

  test "should get index" do
    get flying_sessions_url
    assert_response :success
  end

  test "should get new" do
    get new_flying_session_url
    assert_response :success
  end

  test "should create flying_session" do
    assert_difference("FlyingSession.count") do
      post flying_sessions_url, params: { flying_session: { date_time: @flying_session.date_time, instructor_id: @flying_session.instructor_id, note: @flying_session.note, user_id: @flying_session.user_id, flights: 2 } }
    end

    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "should show flying_session" do
    get flying_session_url(@flying_session)
    assert_response :success
  end

  test "should get edit" do
    get edit_flying_session_url(@flying_session)
    assert_response :success
  end

  test "should update flying_session" do
    patch flying_session_url(@flying_session), params: { flying_session: { date_time: @flying_session.date_time, instructor_id: @flying_session.instructor_id, note: @flying_session.note, user_id: @flying_session.user_id, duration: @flying_session.duration, flights: 3 } }
    assert_redirected_to flying_session_url(@flying_session)
  end

  test "should destroy flying_session" do
    assert_difference("FlyingSession.count", -1) do
      delete flying_session_url(@flying_session)
    end

    assert_redirected_to flying_sessions_url
  end

  test "get_flying_sessions should handle authentication failure" do
    # Mock the authenticate_and_get_cookie method to return nil (authentication failed)
    FlyingSessionsController.any_instance.stubs(:authenticate_and_get_cookie).returns(nil)

    post get_flying_sessions_flying_sessions_url
    assert_redirected_to flying_sessions_url
    assert_match "Failed to authenticate with Windwerk", flash[:alert]
  end

  test "get_flying_sessions should handle empty HTML content" do
    # Mock successful authentication but empty fetch data
    FlyingSessionsController.any_instance.stubs(:authenticate_and_get_cookie).returns("test_cookie")
    FlyingSessionsController.any_instance.stubs(:fetch_windwerk_data).returns(nil)

    post get_flying_sessions_flying_sessions_url
    assert_redirected_to flying_sessions_url
    assert_match "Failed to fetch data from Windwerk after authentication", flash[:alert]
  end

  test "get_flying_sessions should parse HTML and create sessions" do
    # Clean up database to ensure isolated test
    FlyingSession.destroy_all

    # Create a Hana user if it doesn't exist
    User.find_or_create_by(name: "Hana")

    # Read the real HTML content from test file
    html_content = File.read(Rails.root.join("test", "controllers", "test.html"))

    # Mock successful authentication and data fetching
    FlyingSessionsController.any_instance.stubs(:authenticate_and_get_cookie).returns("test_cookie")
    FlyingSessionsController.any_instance.stubs(:fetch_windwerk_data).returns(html_content)

    assert_difference("FlyingSession.count", 7) do # 6 sessions from dropdown + 1 current session
      post get_flying_sessions_flying_sessions_url
    end

    assert_redirected_to flying_sessions_url
    assert_match "Successfully imported 7 flying sessions", flash[:notice]

    # Verify that only the current session (Nov 6, 2025 bis 17:30) has flights
    current_session = FlyingSession.joins(:user)
                                 .where(users: { name: "Hana" })
                                 .where("date_time >= ?", DateTime.new(2025, 11, 6))
                                 .first

    assert_not_nil current_session, "Should find the current session from Nov 6, 2025"
    assert_equal 6, current_session.flights, "Current session should have 6 flights"

    # Verify other sessions have no flights
    other_sessions = FlyingSession.joins(:user)
                                .where(users: { name: "Hana" })
                                .where("date_time < ?", DateTime.new(2025, 11, 6))

    other_sessions.each do |session|
      assert_equal 0, session.flights, "Older sessions should have no flights"
    end
  end

  test "get_flying_sessions should handle HTML without dropdown menu" do
    # Clean up database to ensure isolated test
    FlyingSession.destroy_all

    User.find_or_create_by(name: "Hana")

    html_content = "<html><body><p>No dropdown menu here</p></body></html>"
    # Mock successful authentication but HTML without dropdown
    FlyingSessionsController.any_instance.stubs(:authenticate_and_get_cookie).returns("test_cookie")
    FlyingSessionsController.any_instance.stubs(:fetch_windwerk_data).returns(html_content)

    assert_no_difference("FlyingSession.count") do
      post get_flying_sessions_flying_sessions_url
    end

    assert_redirected_to flying_sessions_url
    assert_match "Successfully imported 0 flying sessions", flash[:notice]
  end

  test "get_flying_sessions should not duplicate existing sessions" do
    # Clean up database to ensure isolated test
    FlyingSession.destroy_all

    User.find_or_create_by(name: "Hana")

    # Create an existing session for Nov 6, 2025 (the current session in the HTML)
    existing_session = FlyingSession.create!(
      date_time: DateTime.new(2025, 11, 6, 17, 30), # Nov 6, 2025 bis 17:30 from HTML
      user: User.find_by(name: "Hana"),
      flights: 0
    )

    # Read the real HTML content from test file
    html_content = File.read(Rails.root.join("test", "controllers", "test.html"))
    # Mock successful authentication and data fetching
    FlyingSessionsController.any_instance.stubs(:authenticate_and_get_cookie).returns("test_cookie")
    FlyingSessionsController.any_instance.stubs(:fetch_windwerk_data).returns(html_content)

    assert_difference("FlyingSession.count", 6) do # 6 new sessions from dropdown (current session already exists)
      post get_flying_sessions_flying_sessions_url
    end

    assert_redirected_to flying_sessions_url
    assert_match "Successfully imported 6 flying sessions", flash[:notice]

    # Verify the existing session now has flights
    existing_session.reload
    assert_equal 6, existing_session.flights, "Existing session should now have 6 flights"
  end

  test "get_flying_sessions should handle network errors gracefully" do
    # Mock successful authentication but network error during data fetch
    FlyingSessionsController.any_instance.stubs(:authenticate_and_get_cookie).returns("test_cookie")
    FlyingSessionsController.any_instance.stubs(:fetch_windwerk_data).raises(StandardError.new("Network error"))

    post get_flying_sessions_flying_sessions_url
    assert_redirected_to flying_sessions_url
    assert_match "An error occurred while fetching data: Network error", flash[:alert]
  end

  test "get_flying_sessions should handle authentication errors gracefully" do
    # Mock authentication failure with exception
    FlyingSessionsController.any_instance.stubs(:authenticate_and_get_cookie).raises(StandardError.new("Authentication failed"))

    post get_flying_sessions_flying_sessions_url
    assert_redirected_to flying_sessions_url
    assert_match "An error occurred while fetching data: Authentication failed", flash[:alert]
  end



  test "should create sessions from timestamp correctly" do
    User.find_or_create_by(name: "Hana")
    controller = FlyingSessionsController.new

    # Test valid timestamp
    timestamp = 1730390400 # 2024-10-30 18:00:00 UTC
    session = controller.send(:create_session_from_timestamp, timestamp)

    assert_not_nil session
    # Use timezone-aware conversion for comparison
    expected_time = Time.at(timestamp).utc.in_time_zone("Europe/Zurich")
    assert_equal expected_time, session.date_time
    assert_equal "Hana", session.user.name

    # Test duplicate session creation (should return existing)
    duplicate_session = controller.send(:create_session_from_timestamp, timestamp)
    assert_equal session.id, duplicate_session.id
  end

  test "should create sessions from date_time string correctly" do
    # Clean up database to ensure isolated test
    FlyingSession.destroy_all

    User.find_or_create_by(name: "Hana")
    controller = FlyingSessionsController.new

    # Test German date format
    session = controller.send(:create_session_from_date_time, "30 Okt. 2025", "18:00")

    assert_not_nil session
    # Use Time.zone to create timezone-aware datetime for comparison
    expected_time = Time.zone.parse("2025-10-30 18:00:00")
    assert_equal expected_time, session.date_time
    assert_equal "Hana", session.user.name

    # Test invalid date format
    invalid_session = controller.send(:create_session_from_date_time, "invalid", "18:00")
    assert_nil invalid_session
  end

  test "should identify current session from HTML button correctly" do
    # Clean up database to ensure isolated test
    FlyingSession.destroy_all

    User.find_or_create_by(name: "Hana")

    # Read the real HTML content from test file
    html_content = File.read(Rails.root.join("test", "controllers", "test.html"))

    # Parse the HTML and look for the current session button
    doc = Nokogiri::HTML(html_content)
    current_button = doc.css("button").find { |btn| btn.text.include?("Flugsession") }

    assert_not_nil current_button, "Should find the current session button"

    strong_element = current_button.css("strong").first
    assert_not_nil strong_element, "Should find strong element in button"

    current_text = strong_element.text.strip
    assert_equal "6 Nov. 2025 bis 17:30", current_text, "Should extract correct current session text"

    # Test that this matches what our parsing logic expects
    match = current_text.match(/(\d{1,2}\s+\w+\.?\s+\d{4})\s+bis\s+(\d{1,2}:\d{2})/)
    assert_not_nil match, "Should match the expected date/time pattern"
    assert_equal "6 Nov. 2025", match[1]
    assert_equal "17:30", match[2]
  end

  test "should parse all session timestamps from dropdown correctly" do
    # Read the real HTML content from test file
    html_content = File.read(Rails.root.join("test", "controllers", "test.html"))

    doc = Nokogiri::HTML(html_content)
    dropdown_menu = doc.css("ul.dropdown-menu").first

    assert_not_nil dropdown_menu, "Should find dropdown menu"

    session_links = dropdown_menu.css("li a")
    assert_equal 6, session_links.length, "Should find 6 session links"

    # Verify the timestamps from the HTML
    expected_timestamps = [1762185600, 1762183800, 1761843600, 1761840000, 1761744600, 1761418800]
    actual_timestamps = []

    session_links.each do |link|
      filter_value = link["href"]&.match(/filter_value=(\d+)/)&.[](1)
      actual_timestamps << filter_value.to_i if filter_value
    end

    assert_equal expected_timestamps, actual_timestamps, "Should extract correct timestamps"
  end
end
