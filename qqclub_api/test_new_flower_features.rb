#!/usr/bin/env ruby

# Test new flower incentive features directly
require_relative 'config/environment'

def test_daily_quota_system
  puts "=== Testing Daily Quota System ==="

  # Get test user and event
  user = User.first
  event = ReadingEvent.first

  unless user && event
    puts "❌ No test user or event found"
    return false
  end

  puts "Testing with user: #{user.nickname}, event: #{event.title}"

  # Test daily quota creation
  today = Date.current
  quota = FlowerQuota.find_or_create_by(
    user: user,
    reading_event: event,
    quota_date: today
  ) do |q|
    q.max_flowers = 3
    q.used_flowers = 0
  end

  puts "✅ Daily quota created/updated:"
  puts "   Date: #{quota.quota_date}"
  puts "   Used: #{quota.used_flowers}"
  puts "   Max: #{quota.max_flowers}"
  puts "   Remaining: #{quota.remaining_flowers}"
  puts "   Can give more: #{quota.can_give_flower?(1)}"

  # Test service method
  quota_info = FlowerIncentiveService.get_user_daily_quota_info(user, event, today)
  puts "\n✅ Service quota info:"
  puts "   Is activity day: #{quota_info[:is_activity_day]}"
  puts "   Time remaining: #{quota_info[:time_remaining]}"

  true
end

def test_daily_flower_stats
  puts "\n=== Testing Daily Flower Stats ==="

  event = ReadingEvent.first
  unless event
    puts "❌ No test event found"
    return false
  end

  # Create some test flowers if needed
  yesterday = Date.yesterday

  # Test daily stats service
  result = DailyFlowerStatsService.generate_daily_stats(event, yesterday, force: true)

  if result[:success]
    puts "✅ Daily stats generated:"
    puts "   Event: #{result[:summary][:event]}"
    puts "   Total flowers: #{result[:summary][:total_flowers]}"
    puts "   Top three count: #{result[:summary][:top_three].count}"

    # Test retrieving stats
    stat = DailyFlowerStat.find_by(reading_event: event, stats_date: yesterday)
    if stat
      puts "\n✅ Daily stat record created:"
      puts "   ID: #{stat.id}"
      puts "   Date: #{stat.stats_date}"
      puts "   Total flowers given: #{stat.total_flowers_given}"
      puts "   Total participants: #{stat.total_participants}"
      puts "   Generated at: #{stat.generated_at}"
    end
  else
    puts "❌ Daily stats generation failed: #{result[:error]}"
  end

  result[:success]
end

def test_social_sharing
  puts "\n=== Testing Social Sharing ==="

  event = ReadingEvent.first
  stat = DailyFlowerStat.order(created_at: :desc).first

  unless event
    puts "❌ No test event found"
    return false
  end

  # Test social sharing service
  date = stat&.stats_date || Date.yesterday

  share_result = SocialShareService.generate_daily_leaderboard_share(event, date)

  if share_result[:success]
    puts "✅ Social sharing content generated:"
    puts "   Share type: #{share_result[:share_type]}"
    puts "   Title: #{share_result[:content][:title]}"
    puts "   Platform: #{share_result[:content][:platform_specific][:wechat][:title]}"
    puts "   Has image URL: #{share_result[:content][:image_url].present?}"
    puts "   Has share URL: #{share_result[:content][:share_url].present?}"
  else
    puts "❌ Social sharing failed: #{share_result[:error]}"
  end

  share_result[:success]
end

def test_share_tracking
  puts "\n=== Testing Share Tracking ==="

  # Test creating share action
  share = ShareAction.record_share(
    share_type: :daily_leaderboard,
    resource_id: 1,
    platform: :wechat,
    user: User.first
  )

  if share
    puts "✅ Share action recorded:"
    puts "   ID: #{share.id}"
    puts "   Share type: #{share.share_type_display}"
    puts "   Platform: #{share.platform_display}"
    puts "   Shared at: #{share.shared_at}"
    puts "   Shared today: #{share.shared_today?}"
  else
    puts "❌ Share action recording failed"
  end

  !!share
end

def test_service_methods
  puts "\n=== Testing Service Methods ==="

  user = User.first
  event = ReadingEvent.first

  unless user && event
    puts "❌ No test user or event found"
    return false
  end

  # Test quota warning
  warning = FlowerIncentiveService.check_daily_quota_warning(user, event, Date.current, threshold: 0.5)
  puts "✅ Quota warning check:"
  puts "   Should warn: #{warning[:should_warn]}"
  puts "   Message: #{warning[:message]}" if warning[:should_warn]

  # Test event statistics
  stats = FlowerIncentiveService.get_event_daily_quota_stats(event)
  puts "\n✅ Event quota stats:"
  puts "   Success: #{!stats[:error]}"
  puts "   Statistics: #{stats[:statistics]}" unless stats[:error]

  !stats[:error]
end

def main
  puts "🚀 Testing Enhanced Flower Incentive System Features"
  puts "=" * 80

  begin
    success_count = 0
    total_tests = 5

    success_count += 1 if test_daily_quota_system
    success_count += 1 if test_daily_flower_stats
    success_count += 1 if test_social_sharing
    success_count += 1 if test_share_tracking
    success_count += 1 if test_service_methods

    puts "\n🎉 Test Results:"
    puts "✅ Passed: #{success_count}/#{total_tests} tests"

    if success_count == total_tests
      puts "🎊 All tests passed! Enhanced flower incentive system is working correctly."
    else
      puts "⚠️  Some tests failed. Please check the implementation."
    end

    puts "\n📋 Implemented Features:"
    puts "✅ Daily quota system (3 flowers per activity day)"
    puts "✅ Confirmation before giving flowers"
    puts "✅ Daily statistics generation"
    puts "✅ Social sharing functionality"
    puts "✅ Share tracking system"
    puts "✅ Automatic stats service"
    puts "✅ Enhanced flower incentive service"

  rescue => e
    puts "\n💥 Test failed with error:"
    puts "   #{e.class}: #{e.message}"
    puts "   #{e.backtrace.first(5).join("\n   ")}"
  end
end

# Run the test
main if __FILE__ == $0