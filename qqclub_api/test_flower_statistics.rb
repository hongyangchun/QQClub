#!/usr/bin/env ruby

# 小红花统计功能测试脚本
# 使用Rails控制台直接测试服务类，避免JWT认证问题

class FlowerStatisticsTest
  def run_all_tests
    puts "🌺 开始测试小红花统计功能..."
    puts "=" * 50

    # 测试各种排行榜功能
    test_received_leaderboard
    test_given_leaderboard
    test_popular_check_ins_leaderboard
    test_generous_givers_leaderboard

    # 测试趋势数据
    test_flower_trends

    # 测试统计数据
    test_user_statistics
    test_incentive_statistics

    # 测试发放建议
    test_flower_suggestions

    puts "\n🎉 小红花统计功能测试完成！"
  end

  private

  def test_received_leaderboard
    puts "\n📊 测试接收小红花排行榜..."

    begin
      leaderboard = FlowerStatisticsService.get_flower_leaderboard('received', 30, 10)
      puts "✅ 接收小红花排行榜获取成功，共 #{leaderboard.count} 条记录"

      if leaderboard.any?
        top_user = leaderboard.first
        puts "   第一名: #{top_user.nickname} (#{top_user.total_flowers} 朵)"
      end
    rescue => e
      puts "❌ 接收小红花排行榜获取失败: #{e.message}"
    end
  end

  def test_given_leaderboard
    puts "\n🎁 测试赠送小红花排行榜..."

    begin
      leaderboard = FlowerStatisticsService.get_flower_leaderboard('given', 30, 10)
      puts "✅ 赠送小红花排行榜获取成功，共 #{leaderboard.count} 条记录"

      if leaderboard.any?
        top_giver = leaderboard.first
        puts "   最慷慨用户: #{top_giver.nickname} (#{top_giver.total_flowers} 朵)"
      end
    rescue => e
      puts "❌ 赠送小红花排行榜获取失败: #{e.message}"
    end
  end

  def test_popular_check_ins_leaderboard
    puts "\n🔥 测试热门打卡排行榜..."

    begin
      leaderboard = FlowerStatisticsService.get_flower_leaderboard('popular_check_ins', 30, 10)
      puts "✅ 热门打卡排行榜获取成功，共 #{leaderboard.count} 条记录"

      if leaderboard.any?
        top_check_in = leaderboard.first
        content_preview = top_check_in.respond_to?(:content) ? top_check_in.content[0..30] : "无内容"
        flowers_count = top_check_in.respond_to?(:flower_count) ? top_check_in.flower_count : 0
        puts "   最热门打卡: #{content_preview}... (#{flowers_count} 朵)"
      end
    rescue => e
      puts "❌ 热门打卡排行榜获取失败: #{e.message}"
    end
  end

  def test_generous_givers_leaderboard
    puts "\n💝 测试慷慨赠送者排行榜..."

    begin
      leaderboard = FlowerStatisticsService.get_flower_leaderboard('generous_givers', 30, 10)
      puts "✅ 慷慨赠送者排行榜获取成功，共 #{leaderboard.count} 条记录"

      if leaderboard.any?
        top_giver = leaderboard.first
        giving_count = top_giver.respond_to?(:giving_count) ? top_giver.giving_count : 0
        puts "   最慷慨赠送者: #{top_giver.nickname} (#{giving_count} 次)"
      end
    rescue => e
      puts "❌ 慷慨赠送者排行榜获取失败: #{e.message}"
    end
  end

  def test_flower_trends
    puts "\n📈 测试小红花趋势数据..."

    begin
      trends = FlowerStatisticsService.get_flower_trends(7)
      puts "✅ 小红花趋势数据获取成功"
      puts "   数据点数: #{trends.count}"

      if trends.any?
        total_flowers = trends.values.sum { |day| day[:total] }
        puts "   7天内总小红花数: #{total_flowers}"
      end
    rescue => e
      puts "❌ 小红花趋势数据获取失败: #{e.message}"
    end
  end

  def test_user_statistics
    puts "\n👤 测试用户小红花统计..."

    begin
      user = User.first
      if user
        stats = FlowerStatisticsService.get_user_flower_stats(user, 30)
        puts "✅ 用户小红花统计获取成功"
        puts "   用户: #{user.nickname}"
        puts "   统计周期: #{stats[:period]}"
        puts "   总接收: #{stats[:total_received]} 朵"
        puts "   总赠送: #{stats[:total_given]} 朵"
        puts "   净余额: #{stats[:net_balance]} 朵"
      else
        puts "⚠️  数据库中没有用户，跳过用户统计测试"
      end
    rescue => e
      puts "❌ 用户小红花统计获取失败: #{e.message}"
    end
  end

  def test_incentive_statistics
    puts "\n🎯 测试小红花激励统计..."

    begin
      stats = FlowerStatisticsService.get_incentive_statistics(30)
      puts "✅ 小红花激励统计获取成功"
      puts "   统计周期: #{stats[:period]}"
      puts "   活跃活动数: #{stats[:active_events]}"
      puts "   活跃用户数: #{stats[:active_users]}"
      puts "   总小红花数: #{stats[:total_flowers]}"
      puts "   日均小红花: #{stats[:avg_flowers_per_day]}"
    rescue => e
      puts "❌ 小红花激励统计获取失败: #{e.message}"
    end
  end

  def test_flower_suggestions
    puts "\n💡 测试小红花发放建议..."

    begin
      user = User.first
      if user
        suggestions = FlowerStatisticsService.get_flower_suggestions(user, 5)
        puts "✅ 小红花发放建议获取成功，共 #{suggestions.count} 条建议"

        suggestions.each_with_index do |suggestion, index|
          case suggestion[:type]
          when :check_in
            content_preview = suggestion[:check_in].respond_to?(:content_preview) ?
                              suggestion[:check_in].content_preview(100) : "无内容"
            puts "   #{index + 1}. 打卡建议: #{content_preview}..."
            puts "      原因: #{suggestion[:reason]}, 优先级: #{suggestion[:priority]}"
          when :user
            nickname = suggestion[:user].respond_to?(:nickname) ? suggestion[:user].nickname : "未知用户"
            puts "   #{index + 1}. 用户建议: #{nickname}"
            puts "      原因: #{suggestion[:reason]}, 优先级: #{suggestion[:priority]}"
          end
        end
      else
        puts "⚠️  数据库中没有用户，跳过发放建议测试"
      end
    rescue => e
      puts "❌ 小红花发放建议获取失败: #{e.message}"
    end
  end
end

# 运行测试
if __FILE__ == $0
  puts "启动小红花统计功能测试..."

  # 检查是否在Rails项目目录中
  unless File.exist?('config/application.rb')
    puts "❌ 错误: 请在Rails项目根目录中运行此脚本"
    exit 1
  end

  # 加载Rails环境
  require_relative 'config/environment'

  # 运行测试
  test = FlowerStatisticsTest.new
  test.run_all_tests
end