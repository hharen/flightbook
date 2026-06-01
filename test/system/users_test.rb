require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  setup do
    @user = users(:anna)
    sign_in users(:hana)
  end

  test "visiting the index" do
    visit users_url
    assert_selector "h1", text: "Users"
  end

  test "should create user" do
    visit users_url
    click_on "New user"

    fill_in "Name", with: "New Test User"
    fill_in "Email", with: "newtest@flightbook.local"
    fill_in "Password", with: "secret123"
    fill_in "Password confirmation", with: "secret123"
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
    test_user = users(:hana).created_users.create!(
      name: "Test User To Delete",
      email: "delete_me@flightbook.local",
      password: "secret123"
    )

    visit users_url

    user_count_before = User.count

    within("tr", text: "Test User To Delete") do
      click_on "Delete"
    end

    sleep 1

    user_count_after = User.count
    assert_equal user_count_before - 1, user_count_after, "User count should decrease by 1"

    assert_current_path users_path
    assert_no_text "Test User To Delete"
  end
end
