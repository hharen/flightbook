#!/usr/bin/env ruby
# Production Timezone Fix Script
# Usage: rails runner scripts/production_timezone_fix.rb [analyze|fix|backup]

require 'date'

class ProductionTimezoneFix
  def initialize
    @incorrect_sessions = []
    @dst_transitions_2025 = {
      cest_start: Date.new(2025, 3, 30),  # Last Sunday of March
      cet_start: Date.new(2025, 10, 26)   # Last Sunday of October
    }
  end

  def run(action = 'analyze')
    puts "🔧 PRODUCTION TIMEZONE FIX SCRIPT"
    puts "=" * 60
    puts "Action: #{action.upcase}"
    puts "Environment: #{Rails.env}"
    puts "Time: #{Time.current}"
    puts

    case action.downcase
    when 'analyze'
      analyze_timezones
    when 'fix'
      fix_timezones
    when 'backup'
      create_backup
    else
      show_usage
    end
  end

  private

  def analyze_timezones
    puts "📊 ANALYZING TIMEZONE ISSUES..."
    puts "-" * 40

    # Get all sessions and analyze them
    total_sessions = FlyingSession.count
    puts "Total flying sessions: #{total_sessions}"

    analyze_each_session

    if @incorrect_sessions.any?
      show_incorrect_sessions
      show_fix_summary
    else
      puts "✅ All sessions have correct timezone information!"
    end

    show_recommendations
  end

  def analyze_each_session
    puts "\n🔍 Checking each session..."

    FlyingSession.find_each.with_index do |session, index|
      print "\rProgress: #{index + 1}/#{FlyingSession.count}" if (index + 1) % 100 == 0

      session_date = session.date_time.to_date
      expected_info = get_expected_timezone_info(session_date)

      actual_zone = session.date_time.zone
      actual_offset = session.date_time.formatted_offset

      if actual_zone != expected_info[:zone] || actual_offset != expected_info[:offset]
        @incorrect_sessions << {
          id: session.id,
          current_time: session.date_time,
          expected_zone: expected_info[:zone],
          expected_offset: expected_info[:offset],
          actual_zone: actual_zone,
          actual_offset: actual_offset,
          issue_type: determine_issue_type(session.date_time, expected_info)
        }
      end
    end

    puts "\rAnalysis complete.                    "
  end

  def get_expected_timezone_info(date)
    if date < @dst_transitions_2025[:cest_start]
      # Before March 30: CET
      { zone: 'CET', offset: '+01:00' }
    elsif date >= @dst_transitions_2025[:cest_start] && date < @dst_transitions_2025[:cet_start]
      # March 30 to October 25: CEST
      { zone: 'CEST', offset: '+02:00' }
    else
      # October 26 onwards: CET
      { zone: 'CET', offset: '+01:00' }
    end
  end

  def determine_issue_type(current_time, expected_info)
    if current_time.zone == 'UTC'
      'utc_instead_of_local'
    elsif expected_info[:zone] == 'CET' && current_time.zone == 'CEST'
      'cest_should_be_cet'
    elsif expected_info[:zone] == 'CEST' && current_time.zone == 'CET'
      'cet_should_be_cest'
    else
      'other_timezone_issue'
    end
  end

  def show_incorrect_sessions
    puts "\n❌ SESSIONS WITH INCORRECT TIMEZONES:"
    puts "-" * 50

    @incorrect_sessions.group_by { |s| s[:issue_type] }.each do |issue_type, sessions|
      puts "\n#{issue_type.upcase.gsub('_', ' ')} (#{sessions.count} sessions):"

      sessions.first(10).each do |session|
        puts "  Session #{session[:id]}:"
        puts "    Current:  #{session[:current_time]} (#{session[:actual_zone]} #{session[:actual_offset]})"
        puts "    Expected: #{session[:expected_zone]} #{session[:expected_offset]}"

        # Calculate corrected time
        corrected_time = calculate_corrected_time(session[:current_time], session[:expected_zone])
        puts "    Fix to:   #{corrected_time}"
        puts
      end

      if sessions.count > 10
        puts "  ... and #{sessions.count - 10} more sessions with the same issue"
        puts
      end
    end
  end

  def calculate_corrected_time(current_time, expected_zone)
    utc_time = current_time.utc

    if expected_zone == 'CET'
      utc_time.in_time_zone('Europe/Zurich').change(offset: '+01:00')
    else # CEST
      utc_time.in_time_zone('Europe/Zurich').change(offset: '+02:00')
    end
  end

  def show_fix_summary
    puts "\n📋 FIX SUMMARY:"
    puts "-" * 30

    by_type = @incorrect_sessions.group_by { |s| s[:issue_type] }

    by_type.each do |type, sessions|
      puts "#{type.gsub('_', ' ').capitalize}: #{sessions.count} sessions"
    end

    puts "\nTotal sessions to fix: #{@incorrect_sessions.count}"
  end

  def show_recommendations
    puts "\n💡 NEXT STEPS:"
    puts "-" * 20

    if @incorrect_sessions.any?
      puts "1. Create backup:"
      puts "   rails runner scripts/production_timezone_fix.rb backup"
      puts
      puts "2. Apply fixes:"
      puts "   rails runner scripts/production_timezone_fix.rb fix"
    else
      puts "✅ No action needed - all timezones are correct!"
    end

    puts "\n📝 Log this analysis for your records."
  end

  def fix_timezones
    if @incorrect_sessions.empty?
      analyze_each_session  # Re-analyze to populate @incorrect_sessions
    end

    if @incorrect_sessions.empty?
      puts "✅ No timezone fixes needed!"
      return
    end

    puts "🔧 APPLYING TIMEZONE FIXES..."
    puts "-" * 40
    puts "Sessions to fix: #{@incorrect_sessions.count}"

    unless Rails.env.development? || ENV['FORCE_PRODUCTION_FIX'] == 'true'
      puts "\n⚠️  PRODUCTION SAFETY CHECK"
      puts "This will modify #{@incorrect_sessions.count} records in production!"
      puts "Set FORCE_PRODUCTION_FIX=true to proceed."
      return
    end

    print "Do you want to proceed? (yes/no): "
    response = STDIN.gets.chomp.downcase

    unless ['yes', 'y'].include?(response)
      puts "❌ Fix cancelled"
      return
    end

    fixed_count = 0
    failed_count = 0

    @incorrect_sessions.each_with_index do |session_info, index|
      begin
        session = FlyingSession.find(session_info[:id])
        corrected_time = calculate_corrected_time(session_info[:current_time], session_info[:expected_zone])

        session.update_column(:date_time, corrected_time)
        fixed_count += 1

        print "\rProgress: #{index + 1}/#{@incorrect_sessions.count} (#{fixed_count} fixed)"
      rescue => e
        failed_count += 1
        puts "\n❌ Failed to fix session #{session_info[:id]}: #{e.message}"
      end
    end

    puts "\n\n✅ FIX COMPLETE:"
    puts "Successfully fixed: #{fixed_count} sessions"
    puts "Failed to fix: #{failed_count} sessions" if failed_count > 0
  end

  def create_backup
    puts "💾 CREATING DATABASE BACKUP..."
    puts "-" * 40

    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    backup_dir = Rails.root.join('tmp', 'backups')
    FileUtils.mkdir_p(backup_dir)

    backup_file = backup_dir.join("timezone_backup_#{timestamp}.sql")

    db_config = Rails.configuration.database_configuration[Rails.env]

    case db_config['adapter']
    when 'sqlite3'
      system("sqlite3 #{db_config['database']} .dump > #{backup_file}")
    when 'postgresql'
      system("pg_dump #{db_config['database']} > #{backup_file}")
    when 'mysql2'
      system("mysqldump #{db_config['database']} > #{backup_file}")
    else
      puts "❌ Unsupported database adapter: #{db_config['adapter']}"
      return
    end

    if File.exist?(backup_file)
      puts "✅ Backup created: #{backup_file}"
      puts "📊 Backup size: #{File.size(backup_file) / 1024 / 1024}MB"
    else
      puts "❌ Backup failed!"
    end
  end

  def show_usage
    puts "Usage: rails runner scripts/production_timezone_fix.rb [ACTION]"
    puts
    puts "Actions:"
    puts "  analyze  - Analyze timezone issues (default)"
    puts "  fix     - Fix timezone issues"
    puts "  backup  - Create database backup"
    puts
    puts "Examples:"
    puts "  rails runner scripts/production_timezone_fix.rb"
    puts "  rails runner scripts/production_timezone_fix.rb analyze"
    puts "  rails runner scripts/production_timezone_fix.rb backup"
    puts "  FORCE_PRODUCTION_FIX=true rails runner scripts/production_timezone_fix.rb fix"
  end
end

# Run the script
action = ARGV[0] || 'analyze'
fixer = ProductionTimezoneFix.new
fixer.run(action)
