require "test_helper"

class FlightsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @flight = flights(:one)
  end

  test "should get index" do
    get flights_url
    assert_response :success
  end

  test "should get new" do
    get new_flight_url
    assert_response :success
  end

  test "should create flight" do
    assert_difference("Flight.count") do
      post flights_url, params: { flight: { flying_session_id: @flight.flying_session_id, duration: @flight.duration } }
    end

    new_flight = Flight.last
    assert_redirected_to new_flight.flying_session
  end

  test "should get edit" do
    get edit_flight_url(@flight)
    assert_response :success
  end

  test "should update flight" do
    patch flight_url(@flight), params: { flight: { flying_session_id: @flight.flying_session_id, duration: @flight.duration } }
    assert_redirected_to @flight.flying_session
  end

  test "should destroy flight" do
    assert_difference("Flight.count", -1) do
      delete flight_url(@flight)
    end

    assert_redirected_to @flight.flying_session
  end

  test "should auto-assign assign incremental flight numbers on create" do
    # flying_session :one already has flights with numbers 1 and 2 from fixtures
    # The next flight should get number 3
    assert_difference("Flight.count") do
      post flights_url, params: {
        flight: {
          flying_session_id: @flight.flying_session_id,
          duration: 5.0,
          note: "Test flight"
        }
      }
    end

    new_flight = Flight.last
    assert_equal 3, new_flight.number
    assert_redirected_to new_flight.flying_session
  end
end
