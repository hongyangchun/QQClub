#!/usr/bin/env ruby

# 测试统计分析功能
require_relative 'config/environment'

puts "开始测试统计分析系统..."

# 测试1: 系统总览统计
puts "\n=== 测试1: 系统总览统计 ==="
begin
  overview = AnalyticsService.system_overview
  puts "✅ 系统总览统计获取成功"
  puts "   用户总数: #{overview[:users][:total_users]}"
  puts "   活动总数: #{overview[:events][:total_events]}"
  puts "   打卡总数: #{overview[:check_ins][:total_check_ins]}"
  puts "   小红花总数: #{overview[:flowers][:total_flowers]}"
  puts "   通知总数: #{overview[:notifications][:total_notifications]}"
rescue => e
  puts "❌ 系统总览统计获取失败: #{e.message}"
  puts e.backtrace.first(3).join("\n")
end

# 测试2: 用户统计
puts "\n=== 测试2: 用户统计 ==="
begin
  user_stats = AnalyticsService.user_statistics
  puts "✅ 用户统计获取成功"
  puts "   活跃用户(7天): #{user_stats[:active_users_7_days]}"
  puts "   新用户(7天): #{user_stats[:new_users_7_days]}"
  puts "   用户角色分布: #{user_stats[:user_roles]}"
rescue => e
  puts "❌ 用户统计获取失败: #{e.message}"
end

# 测试3: 小红花统计
puts "\n=== 测试3: 小红花统计 ==="
begin
  flower_stats = AnalyticsService.flower_statistics
  puts "✅ 小红花统计获取成功"
  puts "   小红花总数: #{flower_stats[:total_flowers]}"
  puts "   今日小红花: #{flower_stats[:flowers_today]}"
  puts "   独立赠送者: #{flower_stats[:unique_givers]}"
  puts "   独立接收者: #{flower_stats[:unique_receivers]}"
  puts "   平均数量: #{flower_stats[:average_amount]}"
rescue => e
  puts "❌ 小红花统计获取失败: #{e.message}"
end

# 测试4: 用户详细分析
puts "\n=== 测试4: 用户详细分析 ==="
begin
  user = User.first
  if user
    user_analytics = AnalyticsService.user_analytics(user, 7)
    puts "✅ 用户详细分析获取成功"
    puts "   用户: #{user.nickname}"
    puts "   参与评分: #{user_analytics[:profile][:participation_score]}"
    puts "   影响力评分: #{user_analytics[:profile][:influence_score]}"
    puts "   活动参与: #{user_analytics[:participation][:events_enrolled]}"
    puts "   互动统计: #{user_analytics[:engagement][:flowers_given]} given, #{user_analytics[:engagement][:flowers_received]} received"
  else
    puts "❌ 没有找到用户数据"
  end
rescue => e
  puts "❌ 用户详细分析获取失败: #{e.message}"
end

# 测试5: 趋势数据
puts "\n=== 测试5: 趋势数据 ==="
begin
  trend_data = AnalyticsService.trend_data(:check_ins, :day, 7)
  puts "✅ 趋势数据获取成功"
  puts "   数据点数量: #{trend_data.count}"
  trend_data.each do |point|
    puts "   #{point[:date]}: #{point[:value]} 次打卡"
  end
rescue => e
  puts "❌ 趋势数据获取失败: #{e.message}"
end

# 测试6: 排行榜
puts "\n=== 测试6: 排行榜 ==="
begin
  flowers_leaderboard = AnalyticsService.leaderboards(:flowers, 3, :all_time)
  puts "✅ 小红花排行榜获取成功"
  flowers_leaderboard.each do |entry|
    puts "   第#{entry[:rank]}名: #{entry[:user][:nickname]} (#{entry[:total_flowers]}朵)"
  end

  check_ins_leaderboard = AnalyticsService.leaderboards(:check_ins, 3, :all_time)
  puts "✅ 打卡排行榜获取成功"
  check_ins_leaderboard.each do |entry|
    puts "   第#{entry[:rank]}名: #{entry[:user][:nickname]} (#{entry[:check_ins_count]}次)"
  end
rescue => e
  puts "❌ 排行榜获取失败: #{e.message}"
end

# 测试7: 参与度统计
puts "\n=== 测试7: 参与度统计 ==="
begin
  engagement_stats = AnalyticsService.engagement_statistics
  puts "✅ 参与度统计获取成功"
  puts "   平均活动参与人数: #{engagement_stats[:average_event_participants]}"
  puts "   平均打卡数/活动: #{engagement_stats[:average_check_ins_per_event]}"
  puts "   平均小红花数/活动: #{engagement_stats[:average_flowers_per_event]}"
  puts "   用户留存率: #{engagement_stats[:user_retention_rate]}%"
rescue => e
  puts "❌ 参与度统计获取失败: #{e.message}"
end

puts "\n统计分析系统测试完成！"