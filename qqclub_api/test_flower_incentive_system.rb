#!/usr/bin/env ruby

# 小红花激励机制系统测试脚本
# 测试配额管理、赠送限制、证书生成等功能

require 'net/http'
require 'json'
require 'uri'

# 配置
API_BASE = 'http://localhost:3000/api/v1'
BASE_URL = 'http://localhost:3000'

# 测试用户令牌
TOKEN = "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJ3eF9vcGVuaWQiOiJ0ZXN0X2RoaF8wMDEiLCJyb2xlIjoidXNlciIsImV4cCI6MTc2MzI2MDU3MywiaWF0IjoxNzYwNjYxNTczLCJ0eXBlIjoiYWNjZXNzIn0.k2y0mzQ24BDRO4vJjeiZ23Dke3b5MB6k9BqJvmuGQ3g"

# 测试方法
def make_request(method, path, data = nil, params = nil)
  uri = URI("#{API_BASE}#{path}")

  if method == :get && params
    uri.query = URI.encode_www_form(params)
  end

  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 30

  request = case method
            when :get
              Net::HTTP::Get.new(uri)
            when :post
              Net::HTTP::Post.new(uri)
            when :put
              Net::HTTP::Put.new(uri)
            when :delete
              Net::HTTP::Delete.new(uri)
            else
              raise "Unsupported HTTP method: #{method}"
            end

  request['Content-Type'] = 'application/json'
  request['Authorization'] = "Bearer #{TOKEN}"

  if data
    request.body = data.to_json
  end

  puts "Request: #{method.upcase} #{uri.path}"
  puts "Request Data: #{data.to_json}" if data

  response = http.request(request)

  puts "Response (#{response.code}): #{response.body[0..200]}#{'...' if response.body.length > 200}"
  puts "-" * 80

  {
    code: response.code.to_i,
    body: response.body
  }
end

def parse_response(response)
  begin
    JSON.parse(response[:body])
  rescue JSON::ParserError
    { error: 'Invalid JSON response', body: response[:body] }
  end
end

def success?(response)
  response[:code] >= 200 && response[:code] < 300
end

# 获取或创建活动
def get_or_create_event
  puts "📚 正在获取测试活动..."

  # 尝试获取现有活动
  response = make_request(:get, '/reading_events', nil, { limit: 1 })

  if success?(response)
    data = parse_response(response)
    if data['success'] && data['data'] && data['data'].any?
      event = data['data'].first
      puts "✅ 使用现有活动: #{event['title']} (ID: #{event['id']})"
      return event['id']
    end
  end

  # 创建新活动
  puts "📝 创建新活动..."
  event_data = {
    reading_event: {
      title: "小红花激励机制测试活动",
      book_name: "测试书籍",
      description: "用于测试小红花激励机制的活动",
      start_date: Date.today.to_s,
      end_date: (Date.today + 7).to_s,
      max_participants: 20,
      min_participants: 2,
      fee_type: "free",
      activity_mode: "note_checkin"
    }
  }

  response = make_request(:post, '/reading_events', event_data)

  if success?(response)
    data = parse_response(response)
    if data['success']
      event_id = data['data']['id']
      puts "✅ 活动创建成功，ID: #{event_id}"
      return event_id
    end
  end

  puts "❌ 活动创建失败"
  exit 1
end

# 用户报名活动
def enroll_in_event(event_id)
  puts "🎯 正在报名活动..."

  enrollment_data = {
    event_enrollment: {
      enrollment_type: "participant"
    }
  }

  response = make_request(:post, "/reading_events/#{event_id}/event_enrollments", enrollment_data)

  if success?(response)
    data = parse_response(response)
    if data['success']
      puts "✅ 活动报名成功"
      return true
    end
  end

  puts "⚠️  活动报名可能已存在或失败"
  false
end

# 测试配额信息获取
def test_quota_info(event_id)
  puts "\n🌸 测试配额信息获取..."

  response = make_request(:get, "/reading_events/#{event_id}/flower_incentives/quota_info")

  if success?(response)
    data = parse_response(response)
    if data['success']
      puts "✅ 配额信息获取成功:"
      puts "   - 用户ID: #{data['data']['user_id']}"
      puts "   - 活动ID: #{data['data']['event_id']}"
      puts "   - 已使用: #{data['data']['used_flowers']}"
      puts "   - 最大额度: #{data['data']['max_flowers']}"
      puts "   - 剩余额度: #{data['data']['remaining_flowers']}"
      puts "   - 使用率: #{data['data']['usage_percentage']}%"
      puts "   - 可继续赠送: #{data['data']['can_give_more'] ? '是' : '否'}"
      return data['data']
    end
  end

  puts "❌ 配额信息获取失败"
  nil
end

# 测试配额初始化（管理员功能）
def test_initialize_quotas(event_id)
  puts "\n🎮 测试配额初始化（管理员功能）..."

  quota_data = {
    max_flowers: 5
  }

  response = make_request(:post, "/reading_events/#{event_id}/flower_incentives/initialize_quotas", quota_data)

  if success?(response)
    data = parse_response(response)
    if data['success']
      puts "✅ 配额初始化成功:"
      puts "   - 活动: #{data['data']['event']['title']}"
      puts "   - 最大配额: #{data['data']['max_flowers']}"
      puts "   - 参与者数量: #{data['data']['participants_count']}"
      return true
    else
      puts "⚠️  #{data['error']}"
    end
  else
    puts "⚠️  配额初始化权限不足或失败"
  end

  false
end

# 测试小红花赠送（预确认）
def test_give_flower_confirmation(event_id)
  puts "\n🎁 测试小红花赠送预确认..."

  # 首先需要获取一个有效的打卡记录
  response = make_request(:get, '/check_ins', nil, { limit: 1 })

  unless success?(response)
    puts "⚠️  无法获取打卡记录，跳过小红花赠送测试"
    return nil
  end

  data = parse_response(response)
  unless data['success'] && data['data'] && data['data'].any?
    puts "⚠️  没有可用的打卡记录，跳过小红花赠送测试"
    return nil
  end

  check_in = data['data'].first
  recipient_id = check_in['user']['id']
  check_in_id = check_in['id']

  # 不能给自己赠送
  if recipient_id == 1 # 假设当前用户ID为1
    puts "⚠️  跳过给自己赠送小红花的测试"
    return nil
  end

  flower_data = {
    recipient_id: recipient_id,
    check_in_id: check_in_id,
    amount: 1,
    comment: "测试小红花赠送",
    flower_type: "regular",
    is_anonymous: false,
    confirm: false # 预确认模式
  }

  response = make_request(:post, "/reading_events/#{event_id}/flower_incentives/give_flower", flower_data)

  if success?(response)
    data = parse_response(response)
    if data['success']
      if data['require_confirmation']
        puts "✅ 小红花赠送预确认成功:"
        puts "   - 接收者: #{data['data']['recipient']['nickname']}"
        puts "   - 打卡内容: #{data['data']['check_in']['content']}"
        puts "   - 赠送数量: #{data['data']['amount']}"
        puts "   - 剩余额度: #{data['data']['remaining_quota']}"
        puts "   - 警告: #{data['data']['warning']}"
        return data['data']
      else
        puts "✅ 小红花赠送直接成功"
        return data['data']
      end
    else
      puts "⚠️  #{data['error']}"
    end
  else
    puts "❌ 小红花赠送预确认失败"
  end

  nil
end

# 测试小红花赠送（确认赠送）
def test_give_flower_confirmed(event_id, confirmation_data)
  return unless confirmation_data

  puts "\n🌟 测试小红花确认赠送..."

  flower_data = {
    recipient_id: confirmation_data['recipient']['id'],
    check_in_id: confirmation_data['check_in']['id'],
    amount: confirmation_data['amount'],
    comment: confirmation_data['comment'],
    flower_type: confirmation_data['flower_type'],
    is_anonymous: confirmation_data['is_anonymous'],
    confirm: true # 确认赠送
  }

  response = make_request(:post, "/reading_events/#{event_id}/flower_incentives/give_flower", flower_data)

  if success?(response)
    data = parse_response(response)
    if data['success']
      puts "✅ 小红花赠送成功:"
      puts "   - 小红花ID: #{data['data']['flower']['id']}"
      puts "   - 剩余额度: #{data['data']['remaining_quota']}"
      puts "   - 警告: #{data['data']['warning']}"
      return data['data']
    else
      puts "❌ #{data['error']}"
    end
  else
    puts "❌ 小红花赠送失败"
  end

  nil
end

# 测试前三名排行榜
def test_top_three(event_id)
  puts "\n🏆 测试前三名排行榜..."

  response = make_request(:get, "/reading_events/#{event_id}/flower_incentives/top_three")

  if success?(response)
    data = parse_response(response)
    if data['success']
      puts "✅ 前三名排行榜获取成功:"
      puts "   - 活动: #{data['data']['event']}"
      puts "   - 总参与者: #{data['data']['total_participants']}"

      if data['data']['top_three'] && data['data']['top_three'].any?
        puts "   - 前三名获奖者:"
        data['data']['top_three'].each_with_index do |winner, index|
          puts "     第#{index + 1}名: #{winner['user']['nickname']} (#{winner['total_flowers']}朵)"
          puts "       荣誉等级: #{winner['honor_level']}"
          puts "       证书ID: #{winner['certificate_id']}"
        end
      else
        puts "   - 暂无获奖者（活动可能未结束或无小红花记录）"
      end

      return data['data']
    else
      puts "⚠️  #{data['error']}"
    end
  else
    puts "⚠️  前三名排行榜获取失败（活动可能未结束）"
  end

  nil
end

# 测试我的证书
def test_my_certificates
  puts "\n🎖️  测试我的证书..."

  response = make_request(:get, '/reading_events/1/flower_incentives/my_certificates')

  if success?(response)
    data = parse_response(response)
    if data['success']
      puts "✅ 我的证书获取成功:"
      puts "   - 用户: #{data['data']['user']['nickname']}"
      puts "   - 证书总数: #{data['data']['total_certificates']}"

      if data['data']['certificates'] && data['data']['certificates'].any?
        puts "   - 证书列表:"
        data['data']['certificates'].each do |cert|
          puts "     * 活动: #{cert['event']}"
          puts "       排名: #{cert['rank']}"
          puts "       小红花数: #{cert['total_flowers']}"
          puts "       荣誉等级: #{cert['honor_level']}"
          puts "       证书ID: #{cert['certificate_id']}"
          puts "       获得时间: #{cert['earned_at']}"
          puts "       证书有效: #{cert['is_valid'] ? '是' : '否'}"
          puts ""
        end
      else
        puts "   - 暂无证书"
      end

      return data['data']
    else
      puts "❌ #{data['error']}"
    end
  else
    puts "❌ 我的证书获取失败"
  end

  nil
end

# 测试证书详情
def test_certificate_detail(certificate_id)
  return unless certificate_id

  puts "\n📜 测试证书详情..."

  response = make_request(:get, '/reading_events/1/flower_incentives/certificate_detail',
                         nil, { certificate_id: certificate_id })

  if success?(response)
    data = parse_response(response)
    if data['success']
      puts "✅ 证书详情获取成功:"
      puts "   - 证书ID: #{data['data']['certificate']['certificate_id']}"
      puts "   - 排名: #{data['data']['certificate']['rank_display']}"
      puts "   - 荣誉等级: #{data['data']['certificate']['honor_level']}"
      puts "   - 小红花数: #{data['data']['certificate']['total_flowers']}"
      puts "   - 用户: #{data['data']['user']['nickname']}"
      puts "   - 活动: #{data['data']['event']['title']}"
      puts "   - 分享链接: #{data['data']['share_url']}"
      puts "   - 证书图片: #{data['data']['certificate_image_url']}"
      puts "   - 证书有效: #{data['data']['certificate']['valid_certificate'] ? '是' : '否'}"
      return data['data']
    else
      puts "❌ #{data['error']}"
    end
  else
    puts "❌ 证书详情获取失败"
  end

  nil
end

# 测试活动证书生成（管理员功能）
def test_finalize_certificates(event_id)
  puts "\n🎊 测试活动证书生成（管理员功能）..."

  response = make_request(:post, "/reading_events/#{event_id}/flower_incentives/finalize_certificates")

  if success?(response)
    data = parse_response(response)
    if data['success']
      puts "✅ 活动证书生成成功:"
      puts "   - 活动: #{data['data']['event']}"
      puts "   - 证书数量: #{data['certificates']&.count || 0}"

      if data['certificates'] && data['certificates'].any?
        puts "   - 生成的证书:"
        data['certificates'].each do |cert|
          puts "     * #{cert['rank']}: #{cert['user']['nickname']} (#{cert['total_flowers']}朵)"
        end
      end

      return data['data']
    else
      puts "⚠️  #{data['error']}"
    end
  else
    puts "⚠️  证书生成权限不足或活动未结束"
  end

  nil
end

# 主测试流程
def main
  puts "开始小红花激励机制系统测试"
  puts "=" * 80

  begin
    # 1. 获取或创建活动
    event_id = get_or_create_event

    # 2. 报名活动
    enroll_in_event(event_id)

    # 3. 测试配额信息获取
    quota_info = test_quota_info(event_id)

    # 4. 测试配额初始化（管理员功能）
    test_initialize_quotas(event_id)

    # 5. 重新获取配额信息
    test_quota_info(event_id)

    # 6. 测试小红花赠送预确认
    confirmation_data = test_give_flower_confirmation(event_id)

    # 7. 测试小红花确认赠送
    if confirmation_data
      test_give_flower_confirmed(event_id, confirmation_data)
    end

    # 8. 测试前三名排行榜
    test_top_three(event_id)

    # 9. 测试我的证书
    certificates = test_my_certificates

    # 10. 测试证书详情（如果有证书）
    if certificates && certificates['certificates'] && certificates['certificates'].any?
      test_certificate_detail(certificates['certificates'].first['certificate_id'])
    end

    # 11. 测试活动证书生成（管理员功能）
    test_finalize_certificates(event_id)

    puts "\n小红花激励机制系统测试完成！"
    puts "=" * 80

  rescue => e
    puts "\n💥 测试过程中发生错误:"
    puts "   #{e.class}: #{e.message}"
    puts "   #{e.backtrace.first(5).join("\n   ")}"
    exit 1
  end
end

# 运行测试
main if __FILE__ == $0