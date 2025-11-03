#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

class FlowerLeaderboardTest
  def initialize(base_url = 'http://localhost:3000')
    @base_url = base_url
    @token = nil
    @current_user_id = nil
  end

  def run_all_tests
    puts "🌺 开始测试小红花排行榜功能..."
    puts "=" * 50

    # 登录获取token
    login

    # 测试各种排行榜功能
    test_received_leaderboard
    test_given_leaderboard
    test_popular_check_ins_leaderboard
    test_generous_givers_leaderboard

    # 测试趋势数据
    test_flower_trends

    # 测试统计数据
    test_user_statistics
    test_event_statistics
    test_incentive_statistics

    # 测试发放建议
    test_flower_suggestions

    # 测试个人排名
    test_my_ranking

    puts "\n🎉 小红花排行榜功能测试完成！"
  end

  private

  def login
    puts "\n🔐 登录测试用户..."

    uri = URI("#{@base_url}/api/auth/mock_login")
    response = http_post(uri, {
      user_info: {
        openid: 'test_dhf_001',
        nickname: '测试用户',
        headimgurl: 'https://example.com/avatar.jpg'
      }
    })

    if response['access_token']
      @token = response['access_token']
      @current_user_id = response['user']['id']
      puts "✅ 登录成功，用户ID: #{@current_user_id}, 用户名: #{response['user']['nickname']}"
    else
      puts "❌ 登录失败: #{response}"
      exit 1
    end
  end

  def test_received_leaderboard
    puts "\n📊 测试接收小红花排行榜..."

    uri = URI("#{@base_url}/api/v1/flower_leaderboards?type=received&period=30&limit=10")
    response = http_get(uri)

    if response['success']
      leaderboard = response['data']['leaderboard']
      puts "✅ 接收小红花排行榜获取成功，共 #{leaderboard.count} 条记录"

      if leaderboard.any?
        top_user = leaderboard.first
        puts "   第一名: #{top_user['nickname']} (#{top_user['total_flowers']} 朵)"
      end
    else
      puts "❌ 接收小红花排行榜获取失败: #{response['message'] || response.inspect}"
    end
  end

  def test_given_leaderboard
    puts "\n🎁 测试赠送小红花排行榜..."

    uri = URI("#{@base_url}/api/v1/flower_leaderboards?type=given&period=30&limit=10")
    response = http_get(uri)

    if response['success']
      leaderboard = response['data']['leaderboard']
      puts "✅ 赠送小红花排行榜获取成功，共 #{leaderboard.count} 条记录"

      if leaderboard.any?
        top_giver = leaderboard.first
        puts "   最慷慨用户: #{top_giver['nickname']} (#{top_giver['total_flowers']} 朵)"
      end
    else
      puts "❌ 赠送小红花排行榜获取失败: #{response['message']}"
    end
  end

  def test_popular_check_ins_leaderboard
    puts "\n🔥 测试热门打卡排行榜..."

    uri = URI("#{@base_url}/api/v1/flower_leaderboards?type=popular_check_ins&period=30&limit=10")
    response = http_get(uri)

    if response['success']
      leaderboard = response['data']['leaderboard']
      puts "✅ 热门打卡排行榜获取成功，共 #{leaderboard.count} 条记录"

      if leaderboard.any?
        top_check_in = leaderboard.first
        puts "   最热门打卡: #{top_check_in['content'][0..30]}... (#{top_check_in['flowers_count']} 朵)"
      end
    else
      puts "❌ 热门打卡排行榜获取失败: #{response['message']}"
    end
  end

  def test_generous_givers_leaderboard
    puts "\n💝 测试慷慨赠送者排行榜..."

    uri = URI("#{@base_url}/api/v1/flower_leaderboards?type=generous_givers&period=30&limit=10")
    response = http_get(uri)

    if response['success']
      leaderboard = response['data']['leaderboard']
      puts "✅ 慷慨赠送者排行榜获取成功，共 #{leaderboard.count} 条记录"

      if leaderboard.any?
        top_giver = leaderboard.first
        puts "   最慷慨赠送者: #{top_giver['nickname']} (#{top_giver['total_flowers']} 次)"
      end
    else
      puts "❌ 慷慨赠送者排行榜获取失败: #{response['message']}"
    end
  end

  def test_flower_trends
    puts "\n📈 测试小红花趋势数据..."

    uri = URI("#{@base_url}/api/v1/flower_leaderboards/trends?days=7")
    response = http_get(uri)

    if response['success']
      trends = response['data']['trends']
      summary = response['data']['summary']
      puts "✅ 小红花趋势数据获取成功"
      puts "   统计周期: #{response['data']['period']}"
      puts "   总小红花数: #{summary['total_flowers']}"
      puts "   日均小红花: #{summary['avg_flowers']}"
      puts "   单日最高: #{summary['max_flowers']}"
      puts "   数据点数: #{trends.count}"
    else
      puts "❌ 小红花趋势数据获取失败: #{response['message']}"
    end
  end

  def test_user_statistics
    puts "\n👤 测试用户小红花统计..."

    uri = URI("#{@base_url}/api/v1/flower_leaderboards/statistics?type=user&id=#{@current_user_id}&days=30")
    response = http_get(uri)

    if response['success']
      stats = response['data']
      puts "✅ 用户小红花统计获取成功"
      puts "   统计周期: #{stats['period']}"
      puts "   总接收: #{stats['total_received']} 朵"
      puts "   总赠送: #{stats['total_given']} 朵"
      puts "   净余额: #{stats['net_balance']} 朵"
    else
      puts "❌ 用户小红花统计获取失败: #{response['message']}"
    end
  end

  def test_event_statistics
    puts "\n📚 测试活动小红花统计..."

    # 假设存在活动ID为1的活动
    uri = URI("#{@base_url}/api/v1/flower_leaderboards/statistics?type=event&id=1&days=30")
    response = http_get(uri)

    if response['success']
      stats = response['data']
      puts "✅ 活动小红花统计获取成功"
      puts "   统计周期: #{stats['period']}"
      puts "   总小红花数: #{stats['total_flowers']}"
      puts "   参与人数: #{stats['participant_count']}"
      puts "   人均小红花: #{stats['avg_flowers_per_participant']}"
    else
      puts "❌ 活动小红花统计获取失败: #{response['message']} (可能是活动不存在)"
    end
  end

  def test_incentive_statistics
    puts "\n🎯 测试小红花激励统计..."

    uri = URI("#{@base_url}/api/v1/flower_leaderboards/statistics?type=incentive&days=30")
    response = http_get(uri)

    if response['success']
      stats = response['data']
      puts "✅ 小红花激励统计获取成功"
      puts "   统计周期: #{stats['period']}"
      puts "   活跃活动数: #{stats['active_events']}"
      puts "   活跃用户数: #{stats['active_users']}"
      puts "   总小红花数: #{stats['total_flowers']}"
      puts "   日均小红花: #{stats['avg_flowers_per_day']}"
    else
      puts "❌ 小红花激励统计获取失败: #{response['message']}"
    end
  end

  def test_flower_suggestions
    puts "\n💡 测试小红花发放建议..."

    uri = URI("#{@base_url}/api/v1/flower_leaderboards/suggestions?limit=5")
    response = http_get(uri)

    if response['success']
      suggestions = response['data']['suggestions']
      puts "✅ 小红花发放建议获取成功，共 #{suggestions.count} 条建议"

      suggestions.each_with_index do |suggestion, index|
        case suggestion['type']
        when 'check_in'
          puts "   #{index + 1}. 打卡建议: #{suggestion['title'][0..30]}..."
          puts "      原因: #{suggestion['reason']}, 优先级: #{suggestion['priority']}"
        when 'user'
          puts "   #{index + 1}. 用户建议: #{suggestion['nickname']}"
          puts "      原因: #{suggestion['reason']}, 优先级: #{suggestion['priority']}"
        end
      end
    else
      puts "❌ 小红花发放建议获取失败: #{response['message']}"
    end
  end

  def test_my_ranking
    puts "\n🏆 测试个人排名..."

    uri = URI("#{@base_url}/api/v1/flower_leaderboards/my_ranking?type=received&period=30")
    response = http_get(uri)

    if response['success']
      data = response['data']
      puts "✅ 个人排名获取成功"
      puts "   排名类型: #{data['type']}"
      puts "   统计周期: #{data['period']}天"
      puts "   我的排名: #{data['my_ranking'] || '未上榜'}"
      puts "   总用户数: #{data['total_users']}"
      puts "   百分比: #{data['percentage']}%"

      if data['my_stats']
        my_stats = data['my_stats']
        puts "   我的统计: 接收 #{my_stats['total_received']} 朵, 赠送 #{my_stats['total_given']} 朵"
      end
    else
      puts "❌ 个人排名获取失败: #{response['message']}"
    end
  end

  def http_get(uri)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@token}"
    request['Content-Type'] = 'application/json'

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end

  def http_post(uri, data)
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = data.to_json

    response = Net::HTTP.start(uri.hostname, uri.port) do |http|
      http.request(request)
    end

    JSON.parse(response.body)
  end
end

# 运行测试
if __FILE__ == $0
  puts "启动小红花排行榜功能测试..."

  # 检查Rails服务器是否运行
  begin
    response = Net::HTTP.get_response(URI('http://localhost:3000/api/health'))
    if response.code != '200'
      puts "❌ Rails服务器未正常运行，请先启动: bundle exec rails server"
      exit 1
    end
  rescue => e
    puts "❌ 无法连接到Rails服务器: #{e.message}"
    puts "请确保Rails服务器正在运行: bundle exec rails server"
    exit 1
  end

  # 运行测试
  test = FlowerLeaderboardTest.new
  test.run_all_tests
end