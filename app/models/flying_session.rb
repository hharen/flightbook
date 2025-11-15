class FlyingSession < ApplicationRecord
  belongs_to :user
  belongs_to :instructor, optional: true

  # Default scope to order by newest sessions first
  default_scope { order(date_time: :desc) }

  # Validations for the new flights column
  validates :flights, presence: true, numericality: {
    greater_than_or_equal_to: 0,
    only_integer: true
  }

  def flight_time
    duration || 0
  end

  def show_flight_time
    flight_time.to_i
  end

  def self.total_flight_time
    sum(:duration)
  end

  # Method to get flights count (now stored as integer)
  def flights_count
    flights
  end
end
