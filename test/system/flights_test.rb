require "application_system_test_case"

class FlightsTest < ApplicationSystemTestCase
  setup do
    @flight = flights(:one)
    @flying_session = @flight.flying_session
  end

  test "viewing flights on flying session show page" do
    visit flying_session_url(@flying_session)

    assert_selector "h2", text: "Flights in this session"
    assert_text "#{@flight.duration} min"
    assert_text @flight.note if @flight.note.present?
  end

  test "should create flight from flying session show page" do
    visit flying_session_url(@flying_session)

    click_on "Add new flight"

    fill_in "Duration", with: "5"
    fill_in "Note", with: "Great flight!"

    # Select the current flying session from the dropdown
    select "#{@flying_session.date_time.to_date.day.ordinalize} of #{@flying_session.date_time.strftime('%B %Y')} - #{@flying_session.date_time.strftime('%R')} with #{@flying_session.instructor.name} (#{@flying_session.user.name})", from: "Flying Session"

    click_on "Create Flight"

    assert_text "Flight was successfully created"
    visit flying_session_url(@flying_session)
    assert_text "5 min"
    assert_text "Great flight!"
  end

  test "should update flight from flying session show page" do
    visit flying_session_url(@flying_session)

    within("table tbody tr", text: "#{@flight.duration} min") do
      click_on "Edit"
    end

    fill_in "Duration", with: @flight.duration + 2
    fill_in "Note", with: "Updated: #{@flight.note}"
    click_on "Update Flight"

    assert_text "Flight was successfully updated"
  end

  test "should destroy flight from flying session show page" do
    visit flying_session_url(@flying_session)

    # Debug: check if the delete button exists
    assert_text "Delete"

    flight_count_before = Flight.count
    click_on "Delete", match: :first

    # Wait for the redirect
    sleep 1

    flight_count_after = Flight.count
    assert_equal flight_count_before - 1, flight_count_after, "Flight count should decrease by 1"

    # We should be redirected to flights index, not the flying session page
    assert_current_path flights_path
    assert_text "Flight was successfully destroyed"
  end
end
