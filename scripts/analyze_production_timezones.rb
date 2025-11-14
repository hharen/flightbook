#!/usr/bin/env ruby

# Production Timezone Analysis Script
# Run this in production to analyze timezone issues before applying fixes

puts "🔍 PRODUCTION TIMEZONE ANALYSIS"
puts "=" * 50

# 1. Check application timezone configuration
puts "\n1. APPLICATION CONFIGURATION:"
puts "   Rails.application.config.time_zone: #{Rails.application.config.time_zone}"
puts "   Time.zone: #{Time.zone}"
puts "   Current time: #{Time.current}"
puts "   System time: #{Time.now}"

# 2. Analyze flying sessions by creation date
puts "\n2. FLYING SESSIONS BY CREATION DATE:"
creation_groups = FlyingSession.group_by { |s| s.created_at.to_date }
creation_groups.keys.sort.each do |date|
  sessions = creation_groups[date]
  puts "   #{date}: #{sessions.count} sessions"

  # Check for timezone inconsistencies within the same day
  timezones = sessions.map { |s| s.date_time.zone }.uniq
  if timezones.count > 1
    puts "     ⚠️  Multiple timezones: #{timezones.join(', ')}"
  end

  # Check for suspicious time patterns
  offsets = sessions.map { |s| s.date_time.formatted_offset }.uniq
  if offsets.count > 1
    puts "     ⚠️  Multiple offsets: #{offsets.join(', ')}"
  end
end

# 3. Look for specific timezone issues
puts "\n3. TIMEZONE ISSUE DETECTION:"

# Find sessions that might be stored in UTC but should be CET/CEST
utc_sessions = FlyingSession.where("date_time LIKE '%+00:00' OR date_time LIKE '%UTC'")
if utc_sessions.any?
  puts "   ⚠️  Found #{utc_sessions.count} sessions with UTC timezone"
  utc_sessions.limit(5).each do |session|
    puts "     Session #{session.id}: #{session.date_time}"
  end
end

# Find sessions with inconsistent DST handling
summer_sessions = FlyingSession.where("strftime('%m', date_time) IN ('06', '07', '08')")
winter_sessions = FlyingSession.where("strftime('%m', date_time) IN ('12', '01', '02')")

summer_offsets = summer_sessions.map { |s| s.date_time.formatted_offset }.uniq
winter_offsets = winter_sessions.map { |s| s.date_time.formatted_offset }.uniq

puts "   Summer sessions (should be +0200): #{summer_offsets.join(', ')}"
puts "   Winter sessions (should be +0100): #{winter_offsets.join(', ')}"

# 4. Check for timestamp conversion issues
puts "\n4. UNIX TIMESTAMP CONVERSION CHECK:"
# Check if any sessions have times that look like they were incorrectly converted
suspicious_times = FlyingSession.where("time(date_time) BETWEEN '00:00:00' AND '02:00:00'")
if suspicious_times.any?
  puts "   ⚠️  Found #{suspicious_times.count} sessions between midnight-2AM (might be timezone conversion errors)"
  suspicious_times.limit(3).each do |session|
    puts "     Session #{session.id}: #{session.date_time} (#{session.date_time.strftime('%A')})"
  end
end

# 5. Generate fix recommendations
puts "\n5. RECOMMENDATIONS:"

total_issues = utc_sessions.count + suspicious_times.count
if total_issues > 0
  puts "   🔧 Run timezone fix script for #{total_issues} potentially affected sessions"
  puts "   💾 Create backup before applying fixes: rake db:backup_before_timezone_fix"
  puts "   🧪 Test fixes: rake db:analyze_timezones"
  puts "   ✅ Apply fixes: rake db:fix_timezones DRY_RUN=false"
else
  puts "   ✅ No obvious timezone issues detected"
  puts "   💡 All sessions appear to have correct timezone information"
end

puts "\n" + "=" * 50
puts "Analysis complete. Review the output above before proceeding with any fixes."
