#!/usr/bin/env ruby

# Test script for new as_json_for_api methods
require_relative 'config/environment'

def test_reading_event_api
  puts "=== Testing ReadingEvent API ==="

  event = ReadingEvent.first
  unless event
    puts "❌ No ReadingEvent found"
    return false
  end

  # Test basic API
  basic_json = event.as_json_for_api
  puts "✅ Basic API: #{basic_json.keys.join(', ')}"

  # Test with includes
  full_json = event.as_json_for_api(
    include_leader: true,
    include_participants: true,
    include_statistics: true,
    include_schedules: true
  )
  puts "✅ Full API with includes: #{full_json.keys.join(', ')}"
  puts "   Has leader: #{full_json[:leader].present?}"
  puts "   Has participants: #{full_json[:participants].present?}"
  puts "   Has statistics: #{full_json[:statistics].present?}"
  puts "   Has schedules: #{full_json[:schedules].present?}"

  true
rescue => e
  puts "❌ ReadingEvent API test failed: #{e.message}"
  false
end

def test_check_in_api
  puts "\n=== Testing CheckIn API ==="

  check_in = CheckIn.first
  unless check_in
    puts "❌ No CheckIn found"
    return false
  end

  # Test basic API
  basic_json = check_in.as_json_for_api
  puts "✅ Basic API: #{basic_json.keys.join(', ')}"

  # Test with includes
  full_json = check_in.as_json_for_api(
    include_user: true,
    include_reading_schedule: true,
    include_reading_event: true,
    include_flowers: true,
    include_content_analysis: true
  )
  puts "✅ Full API with includes: #{full_json.keys.join(', ')}"
  puts "   Has user: #{full_json[:user].present?}"
  puts "   Has schedule: #{full_json[:reading_schedule].present?}"
  puts "   Has event: #{full_json[:reading_event].present?}"
  puts "   Has flowers: #{full_json[:flowers].present?}"
  puts "   Has content analysis: #{full_json[:content_preview].present?}"

  true
rescue => e
  puts "❌ CheckIn API test failed: #{e.message}"
  false
end

def test_event_enrollment_api
  puts "\n=== Testing EventEnrollment API ==="

  enrollment = EventEnrollment.first
  unless enrollment
    puts "❌ No EventEnrollment found"
    return false
  end

  # Test basic API
  basic_json = enrollment.as_json_for_api
  puts "✅ Basic API: #{basic_json.keys.join(', ')}"

  # Test with includes
  full_json = enrollment.as_json_for_api(
    include_user: true,
    include_reading_event: true,
    include_check_ins: true,
    include_flowers: true,
    include_certificates: true,
    include_statistics: true
  )
  puts "✅ Full API with includes: #{full_json.keys.join(', ')}"
  puts "   Has user: #{full_json[:user].present?}"
  puts "   Has event: #{full_json[:reading_event].present?}"
  puts "   Has check-ins: #{full_json[:check_ins].present?}"
  puts "   Has flowers: #{full_json[:flowers].present?}"
  puts "   Has certificates: #{full_json[:certificates].present?}"
  puts "   Has statistics: #{full_json[:statistics].present?}"

  true
rescue => e
  puts "❌ EventEnrollment API test failed: #{e.message}"
  false
end

def test_existing_models
  puts "\n=== Testing Existing Models ==="

  # Test User model
  user = User.first
  if user
    user_json = user.as_json_for_api
    puts "✅ User API: #{user_json.keys.join(', ')}"
  else
    puts "⚠️  No User found"
  end

  # Test ShareAction model
  share = ShareAction.first
  if share
    share_json = share.as_json_for_api
    puts "✅ ShareAction API: #{share_json.keys.join(', ')}"
  else
    puts "⚠️  No ShareAction found"
  end

  true
rescue => e
  puts "❌ Existing models test failed: #{e.message}"
  false
end

def main
  puts "🧪 Testing as_json_for_api Methods"
  puts "=" * 50

  begin
    success_count = 0
    total_tests = 4

    success_count += 1 if test_reading_event_api
    success_count += 1 if test_check_in_api
    success_count += 1 if test_event_enrollment_api
    success_count += 1 if test_existing_models

    puts "\n🎉 Test Results:"
    puts "✅ Passed: #{success_count}/#{total_tests} tests"

    if success_count == total_tests
      puts "🎊 All API methods working correctly!"
    else
      puts "⚠️  Some tests failed."
    end

  rescue => e
    puts "\n💥 Test suite failed:"
    puts "   #{e.class}: #{e.message}"
    puts "   #{e.backtrace.first(3).join("\n   ")}"
  end
end

# Run the test
main if __FILE__ == $0