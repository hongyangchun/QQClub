#!/usr/bin/env ruby

# Load Rails environment
require_relative 'config/environment'
require 'net/http'
require 'json'

puts "🚀 Testing daily leading content APIs..."

# Base URL
BASE_URL = 'http://localhost:3000'

# Test users
USERS = {
  user1: { id: 1, nickname: 'DHH', wx_openid: 'test_dhh_001' },
  user2: { id: 2, nickname: '张三', wx_openid: 'test_user_002' }
}

# Helper method to generate JWT token
def generate_token(user)
  payload = {
    user_id: user[:id],
    wx_openid: user[:wx_openid],
    role: 'user',
    exp: 30.days.from_now.to_i,
    iat: Time.current.to_i,
    type: 'access'
  }
  JWT.encode(payload, Rails.application.credentials.jwt_secret_key || "dev_secret_key")
end

# Helper method to make API requests
def make_request(method, endpoint, token = nil, data = nil)
  uri = URI("#{BASE_URL}#{endpoint}")
  http = Net::HTTP.new(uri.host, uri.port)

  request = case method.upcase
           when 'GET'
             Net::HTTP::Get.new(uri)
           when 'POST'
             req = Net::HTTP::Post.new(uri)
             req['Content-Type'] = 'application/json'
             req.body = data.to_json if data
             req
           when 'PUT'
             req = Net::HTTP::Put.new(uri)
             req['Content-Type'] = 'application/json'
             req.body = data.to_json if data
             req
           when 'DELETE'
             Net::HTTP::Delete.new(uri)
           else
             raise "Unsupported method: #{method}"
           end

  request['Authorization'] = "Bearer #{token}" if token

  response = http.request(request)
  {
    status: response.code.to_i,
    body: response.body
  }
end

# Set up test data
puts "\n📋 Setting up test data..."
event = ReadingEvent.find(6)  # Use existing event
schedules = event.reading_schedules.chronological
schedule = schedules.first  # First schedule with user2 as leader

puts "✅ Using event: #{event.title} (ID: #{event.id})"
puts "✅ Using schedule: Day #{schedule.day_number} - #{schedule.date}"
puts "✅ Schedule leader: #{schedule.daily_leader&.nickname || 'None'}"

# Generate tokens
leader_token = generate_token(USERS[:user1])  # Event leader
user2_token = generate_token(USERS[:user2])   # Schedule leader

# Test 1: Create daily leading content
puts "\n📝 Test 1: Creating daily leading content..."
response = make_request("POST", "/api/v1/reading_events/#{event.id}/reading_schedules/#{schedule.id}/daily_leading", user2_token, {
  content: "今天是第一天阅读，让我们一起开始这个美妙的阅读之旅！今天我们将学习前言和第一章的内容。重点关注作者的主要观点和写作风格。",
  questions: "1. 作者的核心观点是什么？2. 这个观点对我们有什么启发？3. 如何将书中的理论应用到实际生活中？"
})
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Daily leading content creation successful"
  result = JSON.parse(response[:body])
  if result['success']
    leading_data = result['data']
    puts "   Leading content ID: #{leading_data['id']}"
    puts "   Reading suggestion preview: #{leading_data['reading_suggestion'][0..50]}..."
    puts "   Questions preview: #{leading_data['questions'][0..50]}..."
  end
else
  puts "❌ Daily leading content creation failed"
  puts "Response: #{response[:body]}"
end

# Test 2: Get daily leading content
puts "\n📖 Test 2: Retrieving daily leading content..."
response = make_request("GET", "/api/v1/reading_events/#{event.id}/reading_schedules/#{schedule.id}/daily_leading", leader_token)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Daily leading content retrieval successful"
  result = JSON.parse(response[:body])
  if result['success']
    leading_data = result['data']
    if leading_data
      puts "   Leading content ID: #{leading_data['id']}"
      puts "   Reading suggestion: #{leading_data['reading_suggestion'][0..100]}..."
      puts "   Questions: #{leading_data['questions'][0..100]}..."
      puts "   Leader: #{leading_data['leader'] ? leading_data['leader']['nickname'] : 'Unknown'}"
      puts "   Permissions: #{leading_data['permissions']}"
    else
      puts "   No leading content found"
    end
  end
else
  puts "❌ Daily leading content retrieval failed"
  puts "Response: #{response[:body]}"
end

# Test 3: Update daily leading content
puts "\n✏️  Test 3: Updating daily leading content..."
response = make_request("PUT", "/api/v1/reading_events/#{event.id}/reading_schedules/#{schedule.id}/daily_leading", user2_token, {
  content: "今天是第一天阅读，让我们一起开始这个美妙的阅读之旅！今天我们将学习前言和第一章的内容。更新：请重点关注作者的写作风格和论述逻辑。",
  questions: "1. 作者的核心观点是什么？2. 作者的论述逻辑是怎样的？3. 这个观点对我们有什么启发？4. 如何将书中的理论应用到实际生活中？"
})
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Daily leading content update successful"
  result = JSON.parse(response[:body])
  if result['success']
    leading_data = result['data']
    puts "   Updated reading suggestion: #{leading_data['reading_suggestion'][0..100]}..."
    puts "   Updated questions: #{leading_data['questions'][0..100]}..."
  end
else
  puts "❌ Daily leading content update failed"
  puts "Response: #{response[:body]}"
end

# Test 4: Delete daily leading content
puts "\n🗑️  Test 4: Deleting daily leading content..."
response = make_request("DELETE", "/api/v1/reading_events/#{event.id}/reading_schedules/#{schedule.id}/daily_leading", leader_token)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Daily leading content deletion successful"
  result = JSON.parse(response[:body])
  if result['success']
    puts "   Message: #{result['message']}"
  end
else
  puts "❌ Daily leading content deletion failed"
  puts "Response: #{response[:body]}"
end

puts "\n🎉 Daily leading content API testing completed!"