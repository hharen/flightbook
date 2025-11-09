require "test_helper"

class FlightTest < ActiveSupport::TestCase
  def setup
    @flight_one = flights(:one)
    @flight_two = flights(:two)
    @flight_three = flights(:three)
    @flying_session_one = flying_sessions(:one)
    @flying_session_two = flying_sessions(:two)
  end

  test "should auto-generate flight number for first flight in new session" do
    # Create a new flying session that doesn't have any flights yet
    new_user = users(:hana)
    new_session = FlyingSession.create!(
      user: new_user,
      date_time: DateTime.current + 2.hours
    )

    flight = Flight.new(
      flying_session: new_session,
      note: "Test flight"
    )

    assert flight.save
    assert_equal 1, flight.number
  end

  test "should auto-generate incremental flight number based on existing flights" do
    # flying_session :one already has flights with numbers 1 and 2 from fixtures
    # The next flight should get number 3
    flight = Flight.create!(
      flying_session: @flying_session_one,
      note: "Test flight"
    )
    assert_equal 3, flight.number
  end

  test "should validate uniqueness of flight number within same flight session" do
    # flying_session :one already has a flight with number 1 from fixtures
    # Try to create another flight with same number in same session
    duplicate_flight = Flight.new(
      flying_session: @flying_session_one,
      note: "Duplicate flight",
      number: 1
    )

    assert_not duplicate_flight.valid?
    assert_includes duplicate_flight.errors[:number], "has already been taken"
  end

  test "should allow same flight number in different flight sessions" do
    # Both flying_session :one and :two have flights with number 1 from fixtures
    # This should be valid since they're in different sessions
    assert_equal 1, @flight_one.number
    assert_equal 1, @flight_three.number
    assert_equal @flying_session_one, @flight_one.flying_session
    assert_equal @flying_session_two, @flight_three.flying_session

    # Both flights should be valid
    assert @flight_one.valid?
    assert @flight_three.valid?
  end

  test "should auto-number flights independently per session" do
    # flying_session_one already has flights 1 and 2, next should be 3
    new_flight_session1 = Flight.create!(
      flying_session: @flying_session_one,
      note: "Test flight 1"
    )

    # flying_session_two already has flight 1, next should be 2
    new_flight_session2 = Flight.create!(
      flying_session: @flying_session_two,
      note: "Test flight 2"
    )

    # Each session should continue numbering from its highest existing number
    assert_equal 3, new_flight_session1.number
    assert_equal 2, new_flight_session2.number
  end
end
