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

    fill_in "Name", with: @user.name
    click_on "Create User"

    assert_text "User was successfully created"
  end

  test "should update User" do
    visit users_url
    click_on "Edit", match: :first

    fill_in "Name", with: @user.name
    click_on "Update User"

    assert_text "User was successfully updated"
    assert_current_path users_path
  end

  test "should destroy User" do
    visit users_url
    click_on "Delete", match: :first

    assert_text "User was successfully destroyed"
  end
end
