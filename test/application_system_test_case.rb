require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]

  def sign_in(user)
    visit new_session_url
    fill_in "Email", with: user.email
    fill_in "Password", with: "password"
    click_on "Log in"
    assert_button "Log out"  # wait for Turbo navigation to complete
  end
end
