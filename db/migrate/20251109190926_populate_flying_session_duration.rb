class PopulateFlyingSessionDuration < ActiveRecord::Migration[8.1]
  def change
    FlyingSession.find_each do |flying_session|
      total_duration = flying_session.flights.sum(:duration)
      flying_session.update_column(:duration, total_duration)
    end
  end
end
