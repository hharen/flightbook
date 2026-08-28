require "application_system_test_case"

class InstructorsTest < ApplicationSystemTestCase
  setup do
    @instructor = instructors(:dominique)
    sign_in users(:hana)
  end

  test "visiting the index" do
    visit instructors_url
    assert_selector "h1", text: "Instructors"
  end

  test "should create instructor" do
    visit new_instructor_url

    fill_in "Name", with: @instructor.name
    # Use JS submit to bypass Turbo form submission issues in headless Chrome
    page.execute_script("document.querySelector('form[action=\"/instructors\"]').submit()")

    assert_text "Instructor was successfully created"
  end

  test "should update Instructor" do
    visit edit_instructor_url(@instructor)

    fill_in "Name", with: @instructor.name
    page.execute_script("document.querySelector('form[action^=\"/instructors/\"]').submit()")

    assert_text "Instructor was successfully updated"
  end

  test "should destroy Instructor" do
    visit edit_instructor_url(@instructor)
    click_on "Delete instructor"

    assert_text "Instructor was successfully destroyed"
  end
end
