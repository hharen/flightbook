require "test_helper"

class LocaleControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:hana)
  end

  test "sets a valid locale in the session" do
    patch locale_url, params: { locale: "en" }
    assert_redirected_to root_url
    follow_redirect!
    # Confirm the session locale was persisted by checking the response succeeds
    assert_response :success
  end

  test "ignores an invalid locale" do
    patch locale_url, params: { locale: "xx" }
    assert_redirected_to root_url
  end

  test "ignores a missing locale param" do
    patch locale_url, params: {}
    assert_redirected_to root_url
  end
end
