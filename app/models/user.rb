class User < ApplicationRecord
  has_many :flying_sessions, dependent: :destroy

  # Default scope to order by name alphabetically
  default_scope { order(:name) }

  def total_flight_time
    flying_sessions.total_flight_time
  end
end
