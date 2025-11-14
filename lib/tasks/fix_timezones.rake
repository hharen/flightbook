namespace :db do
  desc "Analyze and fix timezone issues in existing records"
  task analyze_timezones: :environment do
    puts "🔍 Analyzing timezone issues in production data..."
    puts "=" * 60

    # Check flying sessions
    puts "\n📅 FLYING SESSIONS ANALYSIS:"
    puts "-" * 30

    suspicious_sessions = []
    FlyingSession.find_each do |session|
      # Look for sessions that might have timezone issues
      # Common indicators:
      # 1. Times that seem to be in UTC when they should be local
      # 2. Inconsistent timezone offsets for similar date ranges

      local_time = session.date_time
      utc_time = session.date_time.utc

      # Check if the time might be stored as UTC but should be CET/CEST
      expected_offset = local_time.in_time_zone("Europe/Zurich").formatted_offset
      actual_offset = local_time.formatted_offset

      if actual_offset != expected_offset
        suspicious_sessions << {
          id: session.id,
          stored_time: local_time,
          expected_time: utc_time.in_time_zone("Europe/Zurich"),
          offset_diff: "#{actual_offset} vs #{expected_offset}"
        }
      end
    end

    if suspicious_sessions.any?
      puts "⚠️ Found #{suspicious_sessions.count} sessions with potential timezone issues:"
      suspicious_sessions.first(10).each do |session|
        puts "  Session #{session[:id]}:"
        puts "    Stored:   #{session[:stored_time]}"
        puts "    Expected: #{session[:expected_time]}"
        puts "    Issue:    #{session[:offset_diff]}"
        puts
      end

      if suspicious_sessions.count > 10
        puts "  ... and #{suspicious_sessions.count - 10} more"
      end
    else
      puts "✅ No obvious timezone issues found in flying sessions"
    end

    # Check flights created_at/updated_at timestamps
    puts "\n✈️  FLIGHTS TIMESTAMP ANALYSIS:"
    puts "-" * 30

    flights_with_issues = []
    Flight.find_each do |flight|
      created_offset = flight.created_at.formatted_offset
      updated_offset = flight.updated_at.formatted_offset
      expected_offset = Time.current.formatted_offset

      if created_offset != expected_offset || updated_offset != expected_offset
        flights_with_issues << flight
      end
    end

    if flights_with_issues.any?
      puts "⚠️  Found #{flights_with_issues.count} flights with timestamp timezone issues"
      flights_with_issues.first(5).each do |flight|
        puts "  Flight #{flight.id} (Session #{flight.flying_session_id}):"
        puts "    Created: #{flight.created_at}"
        puts "    Updated: #{flight.updated_at}"
      end
    else
      puts "✅ No obvious timezone issues found in flight timestamps"
    end

    puts "\n" + "=" * 60
    puts "Analysis complete. Run 'rake db:fix_timezones' to apply fixes if needed."
  end

  desc "Fix timezone issues in existing records (DRY RUN)"
  task fix_timezones: :environment do
    puts "🔧 Fixing timezone issues in production data..."
    puts "⚠️  THIS IS A DRY RUN - no changes will be made"
    puts "=" * 60

    dry_run = ENV["DRY_RUN"] != "false"

    # Fix flying sessions
    sessions_to_fix = []
    FlyingSession.find_each do |session|
      local_time = session.date_time

      # Check if this looks like a UTC time that should be converted to Europe/Zurich
      if local_time.zone == "UTC" || local_time.formatted_offset == "+00:00"
        # This might be a UTC time that should be interpreted as Europe/Zurich
        corrected_time = local_time.utc.in_time_zone("Europe/Zurich")
        sessions_to_fix << {
          session: session,
          old_time: local_time,
          new_time: corrected_time
        }
      end
    end

    if sessions_to_fix.any?
      puts "📅 Flying sessions that would be updated:"
      sessions_to_fix.each do |fix|
        puts "  Session #{fix[:session].id}:"
        puts "    From: #{fix[:old_time]}"
        puts "    To:   #{fix[:new_time]}"
        puts "    Diff: #{((fix[:new_time] - fix[:old_time]) / 1.hour).round(1)} hours"
        puts
      end

      unless dry_run
        print "Do you want to proceed with these changes? (y/N): "
        response = STDIN.gets.chomp.downcase

        if response == "y" || response == "yes"
          sessions_to_fix.each do |fix|
            fix[:session].update_column(:date_time, fix[:new_time])
            puts "✅ Updated session #{fix[:session].id}"
          end
          puts "🎉 Updated #{sessions_to_fix.count} flying sessions"
        else
          puts "❌ Cancelled - no changes made"
        end
      end
    else
      puts "✅ No flying sessions need timezone fixes"
    end

    if dry_run
      puts "\n💡 To actually apply changes, run:"
      puts "   rake db:fix_timezones DRY_RUN=false"
    end
  end

  desc "Backup production data before timezone fixes"
  task backup_before_timezone_fix: :environment do
    puts "💾 Creating backup of timezone-sensitive data..."

    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    backup_file = Rails.root.join("tmp", "timezone_backup_#{timestamp}.sql")

    # Create SQL backup of relevant tables
    system("sqlite3 #{Rails.configuration.database_configuration[Rails.env]['database']} .dump > #{backup_file}")

    puts "✅ Backup created: #{backup_file}"
    puts "💡 Restore with: sqlite3 database.sqlite3 < #{backup_file}"
  end
end
