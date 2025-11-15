class BackfillFlightsCount < ActiveRecord::Migration[8.1]
  def up
    # Use Rails methods to backfill flights column
    puts "Starting backfill of flights count..."

    total_sessions = FlyingSession.count
    updated_count = 0

    FlyingSession.includes(:flights).find_each.with_index do |flying_session, index|
      flight_count = flying_session.flights.count

      # Update the flights column with the actual count
      flying_session.update_column(:flights, flight_count)
      updated_count += 1
    end

    puts "Backfilled flights count for #{updated_count} flying sessions"

    # Verification in development environment
    if Rails.env.development?
      puts "\nVerification - Flying sessions with their flight counts:"
      FlyingSession.includes(:flights).limit(10).each do |session|
        actual_count = session.flights.count
        stored_count = session.read_attribute(:flights)
        status = actual_count == stored_count ? "✓" : "✗"
        puts "#{status} Session #{session.id}: stored=#{stored_count}, actual=#{actual_count}"
      end
    end
  end

  def down
    # Reset all flights counts back to 0 using Rails methods
    puts "Resetting flights count to 0 for all flying sessions..."

    FlyingSession.find_each do |flying_session|
      flying_session.update_column(:flights, 0)
    end

    puts "Reset flights count to 0 for #{FlyingSession.count} flying sessions"
  end
end
