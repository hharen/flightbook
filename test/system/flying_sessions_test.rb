require "application_system_test_case"

class FlyingSessionsTest < ApplicationSystemTestCase
  setup do
    @flying_session = flying_sessions(:one)
  end

  test "visiting the index" do
    visit flying_sessions_url
    assert_selector "h1", text: "Flying sessions"
  end

  test "should create flying session" do
    visit flying_sessions_url
    click_on "New flying session"

    fill_in "Date", with: @flying_session.date_time.to_date
    fill_in "Time", with: @flying_session.date_time.strftime("%H:%M")
    fill_in "Note", with: @flying_session.note
    select @flying_session.user.name, from: "User"
    select @flying_session.instructor.name, from: "Instructor" if @flying_session.instructor
    click_on "Create Flying session"

    assert_text "Flying session was successfully created"
    click_on "Back"
  end

  test "should update Flying session" do
    visit flying_session_url(@flying_session)
    click_on "Edit this flying session", match: :first

    fill_in "Date", with: (@flying_session.date_time + 1.day).to_date
    fill_in "Time", with: @flying_session.date_time.strftime("%H:%M")
    fill_in "Note", with: "Updated: #{@flying_session.note}"
    select @flying_session.user.name, from: "User"
    select @flying_session.instructor.name, from: "Instructor" if @flying_session.instructor
    click_on "Update Flying session"

    assert_text "Flying session was successfully updated"
    click_on "Back"
  end

  test "should destroy Flying session" do
    visit flying_session_url(@flying_session)
    click_on "Destroy this flying session", match: :first

    assert_text "Flying session was successfully destroyed"
  end
end
