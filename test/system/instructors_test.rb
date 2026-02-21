require "application_system_test_case"

class InstructorsTest < ApplicationSystemTestCase
  setup do
    @instructor = instructors(:dominique)
  end

  test "visiting the index" do
    visit instructors_url
    assert_selector "h1", text: "Instructors"
  end

  test "should create instructor" do
    visit instructors_url
    click_on "New instructor"

    fill_in "Name", with: @instructor.name
    click_on "Create Instructor"

    assert_text "Instructor was successfully created"
  end

  test "should update Instructor" do
    visit instructors_url
    click_on @instructor.name, match: :first

    fill_in "Name", with: @instructor.name
    click_on "Update Instructor"

    assert_text "Instructor was successfully updated"
  end

  test "should destroy Instructor" do
    visit instructors_url

    # Find the row containing Dominique and click its Delete button
    within "tr", text: "Dominique" do
      click_on "Delete"
    end

    assert_text "Instructor was successfully destroyed"
  end
end
