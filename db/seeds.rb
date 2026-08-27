# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Load user and instructor fixtures first
puts "Loading user and instructor fixtures..."

begin
  # Load user fixtures
  ActiveRecord::FixtureSet.create_fixtures(Rails.root.join("test", "fixtures"), "users")
  puts "✅ User fixtures loaded successfully"
rescue => e
  puts "⚠️  Warning: Could not load user fixtures: #{e.message}"
end

begin
  # Load instructor fixtures
  ActiveRecord::FixtureSet.create_fixtures(Rails.root.join("test", "fixtures"), "instructors")
  puts "✅ Instructor fixtures loaded successfully"
rescue => e
  puts "⚠️  Warning: Could not load instructor fixtures: #{e.message}"
end

# Find or create users
hana = User.find_or_create_by!(name: "Hana")
hana.update!(admin: true) unless hana.admin?

# Create flying sessions with flights
flying_sessions_data = [
  {
    date_time: DateTime.parse("2025-04-29 12:30"),
    note: "flight school level one",
    instructor: "Craig",
    flights_count: 6,
    flight_duration: 2.5
  },
  {
    date_time: DateTime.parse("2025-05-01 19:30"),
    note: "flight school level two",
    instructor: "Marius",
    flights_count: 6,
    flight_duration: 2.5
  },
  {
    date_time: DateTime.parse("2025-05-13 14:30"),
    note: "flight school level three",
    instructor: "Lena",
    flights_count: 6,
    flight_duration: 2.5
  },
  {
    date_time: DateTime.parse("2025-08-01 18:30"),
    note: "flight school level four",
    instructor: "Craig",
    flights_count: 6,
    flight_duration: 2.5
  },
  {
    date_time: DateTime.parse("2025-08-26 00:00"),
    note: nil,
    instructor: "Cris",
    flights_count: 4,
    flight_duration: 2.5
  },
  {
    date_time: DateTime.parse("2025-09-02 13:00"),
    note: nil,
    instructor: "Cris",
    flights_count: 5,
    flight_duration: 2.5
  },
  {
    date_time: DateTime.parse("2025-09-02 00:00"),
    note: "Gutes Bauchfliegen, stabiler Bogen.",
    instructor: "Cris",
    flights_count: 5,
    flight_duration: 2.5
  },
  {
    date_time: DateTime.parse("2025-09-08 13:00"),
    note: "R\u00fcckenfliegen und Beinarbeit ge\u00fcbt. N\u00e4chstes Mal wieder auf die Beinarbeit achten. Drehungen von Bauch zu R\u00fccken und zur\u00fcck.",
    instructor: "Chris",
    flights_count: 5,
    flight_duration: 3
  },
  {
    date_time: DateTime.parse("2025-09-08 14:00"),
    note: "Ganze Session zu Sitfly-Grundlagen. Begonnen auf dem Boden mit der K\u00f6rperposition: neutrale Wirbels\u00e4ule, Knie ca. 90\u00b0 gebeugt, Arme zur Balance ausgestreckt, und wie kleine Kinn-/Kniebewegungen die Fallgeschwindigkeit ver\u00e4ndern. Im Tunnel haben wir zuerst Stabilit\u00e4t im Sitz erarbeitet, bevor Bewegung dazukam, danach kontrollierte Drehungen ge\u00fcbt.\n\nN\u00e4chstes Mal: Schultern gerade halten. Im Debrief ging es um typische Verspannungspunkte (Schultern, H\u00e4nde) und ein paar Trocken\u00fcbungen f\u00fcr die n\u00e4chste Session.",
    instructor: "Chris",
    flights_count: 5,
    flight_duration: 4
  }
]

flying_sessions_data.each do |session_data|
  # Find instructor by name if specified
  instructor = session_data[:instructor] ? Instructor.find_by(name: session_data[:instructor]) : nil

  # Create or update the flying session
  fs = FlyingSession.find_or_initialize_by(
    user: hana,
    date_time: session_data[:date_time]
  )
  fs.note = session_data[:note]
  fs.instructor = instructor
  fs.flights = session_data[:flights_count]
  fs.duration = (session_data[:flights_count] * session_data[:flight_duration]).to_i if session_data[:flights_count] > 0
  fs.save!

  puts "Created/found session on #{session_data[:date_time]}"
end

puts "Seeds completed successfully!"
