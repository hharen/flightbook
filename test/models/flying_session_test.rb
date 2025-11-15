require "test_helper"

class FlyingSessionTest < ActiveSupport::TestCase
  test "flights_count method should return flights value" do
    flying_session = flying_sessions(:one)
    assert_equal flying_session.flights, flying_session.flights_count
  end
end
