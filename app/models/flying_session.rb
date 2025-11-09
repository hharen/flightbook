class FlyingSession < ApplicationRecord
  belongs_to :user
  belongs_to :instructor, optional: true
  has_many :flights, dependent: :destroy

  # Default scope to order by newest sessions first
  default_scope { order(date_time: :desc) }

  def flight_time
    duration || 0
  end

  def show_flight_time
    flight_time.to_i
  end

  def self.total_flight_time
    sum(:duration)
  end
end
