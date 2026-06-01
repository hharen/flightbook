require "application_system_test_case"

class FlyingSessionsTest < ApplicationSystemTestCase
  setup do
    @flying_session = flying_sessions(:one)
    sign_in users(:hana)
  end

  test "visiting the index" do
    visit flying_sessions_url
    assert_selector "h1", text: "Flying sessions"
  end

  test "should create flying session" do
    visit new_flying_session_url
    assert_selector "h1", text: "New flying session"

    fill_in "Note", with: @flying_session.note
    select @flying_session.user.name, from: "User"
    select @flying_session.instructor.name, from: "Instructor"

    # HH: it's ugly but better than skip for now
    # Chrome's native date/time validation blocks button click; set values and
    # submit via JS to bypass HTML5 validation and reach the server directly.
    # Use the form's action to avoid selecting the navbar logout form.
    page.execute_script(
      "var f = document.querySelector('form[action*=flying_sessions]');" \
      "document.getElementById('flying_session_date').value = arguments[0];" \
      "document.getElementById('flying_session_time').value = arguments[1];" \
      "f.submit();",
      @flying_session.date_time.strftime("%Y-%m-%d"),
      @flying_session.date_time.strftime("%H:%M")
    )

    assert_text "Flying session was successfully created"
  end

  test "should update Flying session" do
    visit flying_session_url(@flying_session)
    click_on "Edit", match: :first

    fill_in "Note", with: "Updated: #{@flying_session.note}"
    select @flying_session.user.name, from: "User"
    select @flying_session.instructor.name, from: "Instructor" if @flying_session.instructor

    page.execute_script(
      "var f = document.querySelector('form[action*=flying_sessions]');" \
      "document.getElementById('flying_session_date').value = arguments[0];" \
      "document.getElementById('flying_session_time').value = arguments[1];" \
      "f.submit();",
      (@flying_session.date_time + 1.day).strftime("%Y-%m-%d"),
      @flying_session.date_time.strftime("%H:%M")
    )

    assert_text "Flying session was successfully updated"
  end

  test "should destroy Flying session" do
    visit flying_session_url(@flying_session)
    accept_confirm("Are you sure?") do
      click_on "Delete", match: :first
    end

    assert_text "Flying session was successfully destroyed"
  end
end
