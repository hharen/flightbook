#!/usr/bin/env ruby

puts "🔧 DETAILED TIMEZONE ISSUE ANALYSIS"
puts "=" * 60

# Current timezone rules for Europe/Zurich:
# - CEST (UTC+2): Last Sunday in March to Last Sunday in October
# - CET (UTC+1): Last Sunday in October to Last Sunday in March

puts "\n📅 ANALYZING SESSIONS WITH INCORRECT TIMEZONES:"
puts "-" * 50

# Find sessions that should be CET but are marked as CEST
incorrect_sessions = []

FlyingSession.all.each do |session|
  session_date = session.date_time
  expected_zone = nil

  # Determine what the timezone SHOULD be based on the date
  # 2025 DST transition dates:
  # - CEST starts: March 30, 2025 (last Sunday of March)
  # - CET starts: October 26, 2025 (last Sunday of October)

  if session_date.month >= 4 && session_date.month <= 9
    # April through September: definitely CEST
    expected_zone = "CEST"
    expected_offset = "+02:00"
  elsif session_date.month >= 11 || session_date.month <= 2
    # November through February: definitely CET
    expected_zone = "CET"
    expected_offset = "+01:00"
  elsif session_date.month == 3
    # March: CET until March 30, then CEST
    if session_date.day >= 30
      expected_zone = "CEST"
      expected_offset = "+02:00"
    else
      expected_zone = "CET"
      expected_offset = "+01:00"
    end
  elsif session_date.month == 10
    # October: CEST until October 26, then CET
    if session_date.day >= 26
      expected_zone = "CET"
      expected_offset = "+01:00"
    else
      expected_zone = "CEST"
      expected_offset = "+02:00"
    end
  end

  actual_zone = session_date.zone
  actual_offset = session_date.formatted_offset

  if actual_zone != expected_zone || actual_offset != expected_offset
    incorrect_sessions << {
      id: session.id,
      date_time: session_date,
      actual_zone: actual_zone,
      actual_offset: actual_offset,
      expected_zone: expected_zone,
      expected_offset: expected_offset,
      created_at: session.created_at
    }
  end
end

if incorrect_sessions.any?
  puts "⚠️  Found #{incorrect_sessions.count} sessions with incorrect timezones:\n"

  incorrect_sessions.each do |session|
    puts "Session #{session[:id]}:"
    puts "  Date/Time: #{session[:date_time]}"
    puts "  Current:   #{session[:actual_zone]} (#{session[:actual_offset]})"
    puts "  Should be: #{session[:expected_zone]} (#{session[:expected_offset]})"
    puts "  Created:   #{session[:created_at]}"

    # Calculate what the corrected time should be
    current_utc = session[:date_time].utc
    if session[:expected_zone] == "CET"
      corrected_time = current_utc.in_time_zone("Europe/Zurich").change(offset: "+01:00")
    else
      corrected_time = current_utc.in_time_zone("Europe/Zurich").change(offset: "+02:00")
    end

    puts "  Fix to:    #{corrected_time}"
    puts "  UTC diff:  #{((corrected_time.utc - current_utc) / 1.hour).round(1)} hours"
    puts
  end

  puts "\n🔧 RECOMMENDED FIXES:"
  puts "-" * 30

  # Group by type of fix needed
  cet_fixes = incorrect_sessions.select { |s| s[:expected_zone] == "CET" }
  cest_fixes = incorrect_sessions.select { |s| s[:expected_zone] == "CEST" }

  if cet_fixes.any?
    puts "Convert to CET (winter time): #{cet_fixes.count} sessions"
    cet_fixes.each { |s| puts "  - Session #{s[:id]} (#{s[:date_time].strftime('%Y-%m-%d')})" }
  end

  if cest_fixes.any?
    puts "Convert to CEST (summer time): #{cest_fixes.count} sessions"
    cest_fixes.each { |s| puts "  - Session #{s[:id]} (#{s[:date_time].strftime('%Y-%m-%d')})" }
  end

  puts "\n💡 To fix these issues:"
  puts "1. Backup database: rake db:backup_before_timezone_fix"
  puts "2. Run fix script: rake db:fix_timezones DRY_RUN=false"

else
  puts "✅ All sessions have correct timezone information!"
end

puts "\n" + "=" * 60
puts "Detailed analysis complete."
