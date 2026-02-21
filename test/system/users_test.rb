require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  setup do
    @user = users(:hana)
  end

  test "visiting the index" do
    visit users_url
    assert_selector "h1", text: "Users"
  end

  test "should create user" do
    visit users_url
    click_on "New user"

    fill_in "Name", with: "New Test User"
    click_on "Create User"

    assert_text "User was successfully created"
  end

  test "should update User" do
    visit users_url
    click_on @user.name, match: :first

    fill_in "Name", with: @user.name
    click_on "Update User"

    assert_text "User was successfully updated"
    assert_current_path users_path
  end

  test "should destroy User" do
    # Clean up any users created by other tests (except fixtures)
    User.where.not(name: ["Hana", "Anna"]).destroy_all

    # Create a test user specifically for deletion
    test_user = User.create!(name: "Test User To Delete")

    visit users_url

    # Count users before deletion
    user_count_before = User.count

    # Find and delete the specific test user
    within("tr", text: "Test User To Delete") do
      click_on "Delete"
    end

    # Wait for the page to reload and navigation to complete
    sleep 1

    # Check that user count decreased
    user_count_after = User.count
    assert_equal user_count_before - 1, user_count_after, "User count should decrease by 1"

    # We should still be on the users page
    assert_current_path users_path

    # The test user should be gone
    assert_no_text "Test User To Delete"
  end
end
