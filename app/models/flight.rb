class Flight < ApplicationRecord
  belongs_to :flying_session

  before_validation :set_flight_number, on: :create

  validates :number, presence: true, uniqueness: { scope: :flying_session_id }, numericality: { greater_than: 0, only_integer: true }

  def show_duration
    return "-" if duration.nil?

    "%.1f" % duration
  end

  private

  def set_flight_number
    # Only auto-assign if number is nil (not explicitly set, even to 0)
    return unless number.nil?

    # Find the highest flight number within this flight session
    last_flight_number = Flight.where(flying_session_id: flying_session_id).maximum(:number)
    self.number = last_flight_number ? last_flight_number + 1 : 1
  end
end
