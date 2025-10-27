require "test_helper"

class FlyingSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @flying_session = flying_sessions(:one)
  end

  test "should get index" do
    get flying_sessions_url
    assert_response :success
  end

  test "should get new" do
    get new_flying_session_url
    assert_response :success
  end

  test "should create flying_session" do
    assert_difference("FlyingSession.count") do
      post flying_sessions_url, params: { flying_session: { date: @flying_session.date, flight_time: @flying_session.flight_time, instructor_id: @flying_session.instructor_id, note: @flying_session.note, time: @flying_session.time, user_id: @flying_session.user_id } }
    end

    assert_redirected_to flying_session_url(FlyingSession.last)
  end

  test "should show flying_session" do
    get flying_session_url(@flying_session)
    assert_response :success
  end

  test "should get edit" do
    get edit_flying_session_url(@flying_session)
    assert_response :success
  end

  test "should update flying_session" do
    patch flying_session_url(@flying_session), params: { flying_session: { date: @flying_session.date, flight_time: @flying_session.flight_time, instructor_id: @flying_session.instructor_id, note: @flying_session.note, time: @flying_session.time, user_id: @flying_session.user_id } }
    assert_redirected_to flying_session_url(@flying_session)
  end

  test "should destroy flying_session" do
    assert_difference("FlyingSession.count", -1) do
      delete flying_session_url(@flying_session)
    end

    assert_redirected_to flying_sessions_url
  end
end
