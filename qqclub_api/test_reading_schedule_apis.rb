#!/usr/bin/env ruby

# Load Rails environment
require_relative 'config/environment'
require 'net/http'
require 'json'

puts "🚀 Starting comprehensive reading schedule API testing..."

# Base URL
BASE_URL = 'http://localhost:3000'

# Test users
USERS = {
  user1: { id: 1, nickname: 'DHH', wx_openid: 'test_dhh_001' },
  user2: { id: 2, nickname: '张三', wx_openid: 'test_user_002' },
  user3: { id: 3, nickname: '测试小组长', wx_openid: 'test_leader_001' }
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

# Test 1: Create or find test event with schedules
puts "\n📋 Test 1: Setting up test event with reading schedules..."
event = ReadingEvent.where(title: "API测试阅读计划活动").first

if event.nil?
  puts "Creating new test event with schedules..."
  event = ReadingEvent.create!(
    title: "API测试阅读计划活动",
    book_name: "API测试书籍",
    start_date: Date.today,
    end_date: Date.today + 7.days,
    description: "用于API测试的阅读计划活动",
    leader: User.find(USERS[:user1][:id]),
    status: :in_progress,
    approval_status: :approved,
    max_participants: 5,
    min_participants: 1,
    activity_mode: :note_checkin,
    leader_assignment_type: :voluntary
  )

  # 让用户2和用户3都报名参与活动
  enrollment2 = EventEnrollment.create!(
    reading_event: event,
    user: User.find(USERS[:user2][:id]),
    enrollment_type: :participant,
    status: :enrolled,
    enrollment_date: Time.current
  )

  enrollment3 = EventEnrollment.create!(
    reading_event: event,
    user: User.find(USERS[:user3][:id]),
    enrollment_type: :participant,
    status: :enrolled,
    enrollment_date: Time.current
  )

  # 手动创建阅读计划
  schedules = []
  (0..6).each do |day|
    schedule = event.reading_schedules.create!(
      day_number: day + 1,
      date: event.start_date + day.days,
      reading_progress: "第#{day + 1}章内容",
      daily_leader: day == 0 ? User.find(USERS[:user2][:id]) : nil
    )
    schedules << schedule
  end

  puts "✅ Created test event: #{event.id} with #{schedules.length} reading schedules"
  puts "✅ Created enrollment for user2: #{enrollment2.id}"
  puts "✅ Created enrollment for user3: #{enrollment3.id}"
else
  puts "✅ Found existing test event: #{event.id}"
  schedules = event.reading_schedules.chronological
  puts "   Found #{schedules.length} reading schedules"

  # 如果没有计划，创建它们
  if schedules.empty?
    # 确保用户2和用户3都已报名
    [USERS[:user2], USERS[:user3]].each do |user|
      unless event.user_enrolled?(User.find(user[:id]))
        enrollment = EventEnrollment.create!(
          reading_event: event,
          user: User.find(user[:id]),
          enrollment_type: :participant,
          status: :enrolled,
          enrollment_date: Time.current
        )
        puts "✅ Created enrollment for #{user[:nickname]}: #{enrollment.id}"
      end
    end

    # 手动创建阅读计划
    schedules = []
    (0..6).each do |day|
      schedule = event.reading_schedules.create!(
        day_number: day + 1,
        date: event.start_date + day.days,
        reading_progress: "第#{day + 1}章内容",
        daily_leader: day == 0 ? User.find(USERS[:user2][:id]) : nil
      )
      schedules << schedule
    end
    puts "   Created #{schedules.length} reading schedules"
  end
end

# Test 2: Generate tokens for different users
puts "\n🔑 Test 2: Generating authentication tokens..."
tokens = {}
USERS.each do |key, user|
  tokens[key] = generate_token(user)
  puts "✅ Generated token for #{user[:nickname]} (ID: #{user[:id]})"
end

# Test 3: Test reading schedules list API
puts "\n📊 Test 3: Testing reading schedules list API..."
leader_token = tokens[:user1]  # Event leader

response = make_request("GET", "/api/v1/reading_events/#{event.id}/reading_schedules", leader_token)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Reading schedules list retrieval successful"
  result = JSON.parse(response[:body])
  if result['success']
    schedules_data = result['data']
    puts "   Total schedules: #{schedules_data.length}"
    schedules_data.each_with_index do |schedule, index|
      puts "   #{index + 1}. Day #{schedule['day_number']} - #{schedule['date']}"
      puts "      Progress: #{schedule['reading_progress']}"
      puts "      Leader: #{schedule['daily_leader'] ? schedule['daily_leader']['nickname'] : 'None'}"
      puts "      Has leading content: #{schedule['daily_leading'] ? 'Yes' : 'No'}"
    end
  end
else
  puts "❌ Reading schedules list retrieval failed"
  puts "Response: #{response[:body]}"
end

# Test 4: Test reading schedule detail API
puts "\n🔍 Test 4: Testing reading schedule detail API..."
if schedules.any?
  schedule_id = schedules.first.id
  response = make_request("GET", "/api/v1/reading_schedules/#{schedule_id}?reading_event_id=#{event.id}", leader_token)
  puts "Response status: #{response[:status]}"

  if response[:status] == 200
    puts "✅ Reading schedule detail retrieval successful"
    result = JSON.parse(response[:body])
    if result['success']
      schedule_data = result['data']
      puts "   Schedule: Day #{schedule_data['day_number']} - #{schedule_data['date']}"
      puts "   Reading progress: #{schedule_data['reading_progress']}"
      puts "   Leader: #{schedule_data['daily_leader'] ? schedule_data['daily_leader']['nickname'] : 'None'}"
      puts "   Status info: #{schedule_data['status_info']}"
      puts "   Permissions: #{schedule_data['permissions']}"
    end
  else
    puts "❌ Reading schedule detail retrieval failed"
    puts "Response: #{response[:body]}"
  end
else
  puts "⚠️  No schedules found for detail test"
end

# Test 5: Test leader assignment API
puts "\n👥 Test 5: Testing leader assignment API..."
if schedules.length > 1
  schedule_to_assign = schedules[1]  # Second schedule
  user3_id = USERS[:user3][:id]

  response = make_request("POST", "/api/v1/reading_schedules/#{schedule_to_assign.id}/assign_leader?reading_event_id=#{event.id}", leader_token, {
    user_id: user3_id
  })
  puts "Response status: #{response[:status]}"

  if response[:status] == 200
    puts "✅ Leader assignment successful"
    result = JSON.parse(response[:body])
    if result['success']
      schedule_data = result['data']
      puts "   Assigned leader: #{schedule_data['daily_leader']['nickname']}"
    end
  else
    puts "❌ Leader assignment failed"
    puts "Response: #{response[:body]}"
  end
else
  puts "⚠️  Not enough schedules for leader assignment test"
end

# Test 6: Test daily leading content creation API
puts "\n📝 Test 6: Testing daily leading content creation API..."
if schedules.any?
  schedule = schedules.first
  user2_token = tokens[:user2]  # User2 should be the leader of first schedule

  # First try to create leading content
  response = make_request("POST", "/api/v1/reading_schedules/#{schedule.id}/daily_leading?reading_event_id=#{event.id}", user2_token, {
    content: "今天是第一天阅读，让我们一起开始这个美妙的阅读之旅！今天我们将学习前言和第一章的内容。",
    reading_pages: "前言 + 第1-20页"
  })
  puts "Response status: #{response[:status]}"

  if response[:status] == 200
    puts "✅ Daily leading content creation successful"
    result = JSON.parse(response[:body])
    if result['success']
      leading_data = result['data']
      puts "   Leading content ID: #{leading_data['id']}"
      puts "   Content preview: #{leading_data['content'][0..50]}..."
      puts "   Reading pages: #{leading_data['reading_pages']}"
    end
  else
    puts "❌ Daily leading content creation failed"
    puts "Response: #{response[:body]}"
  end
else
  puts "⚠️  No schedules found for daily leading content creation test"
end

# Test 7: Test daily leading content retrieval API
puts "\n📖 Test 7: Testing daily leading content retrieval API..."
if schedules.any?
  schedule = schedules.first

  response = make_request("GET", "/api/v1/reading_schedules/#{schedule.id}/daily_leading?reading_event_id=#{event.id}", leader_token)
  puts "Response status: #{response[:status]}"

  if response[:status] == 200
    puts "✅ Daily leading content retrieval successful"
    result = JSON.parse(response[:body])
    if result['success']
      leading_data = result['data']
      if leading_data
        puts "   Leading content ID: #{leading_data['id']}"
        puts "   Content: #{leading_data['content'][0..100]}..."
        puts "   Reading pages: #{leading_data['reading_pages']}"
        puts "   Created by: #{leading_data['created_by'] ? leading_data['created_by']['nickname'] : 'Unknown'}"
        puts "   Permissions: #{leading_data['permissions']}"
      else
        puts "   No leading content found"
      end
    end
  else
    puts "❌ Daily leading content retrieval failed"
    puts "Response: #{response[:body]}"
  end
else
  puts "⚠️  No schedules found for daily leading content retrieval test"
end

# Test 8: Test daily leading content update API
puts "\n✏️  Test 8: Testing daily leading content update API..."
if schedules.any?
  schedule = schedules.first
  user2_token = tokens[:user2]

  response = make_request("PUT", "/api/v1/reading_schedules/#{schedule.id}/daily_leading?reading_event_id=#{event.id}", user2_token, {
    content: "今天是第一天阅读，让我们一起开始这个美妙的阅读之旅！今天我们将学习前言和第一章的内容。更新：请重点关注作者的写作风格。",
    reading_pages: "前言 + 第1-25页"
  })
  puts "Response status: #{response[:status]}"

  if response[:status] == 200
    puts "✅ Daily leading content update successful"
    result = JSON.parse(response[:body])
    if result['success']
      leading_data = result['data']
      puts "   Updated content preview: #{leading_data['content'][0..100]}..."
      puts "   Updated reading pages: #{leading_data['reading_pages']}"
    end
  else
    puts "❌ Daily leading content update failed"
    puts "Response: #{response[:body]}"
  end
else
  puts "⚠️  No schedules found for daily leading content update test"
end

# Test 9: Test leader removal API
puts "\n🚫 Test 9: Testing leader removal API..."
if schedules.length > 1
  schedule_to_remove = schedules[1]  # Second schedule where we assigned user3 as leader

  response = make_request("POST", "/api/v1/reading_schedules/#{schedule_to_remove.id}/remove_leader?reading_event_id=#{event.id}", leader_token)
  puts "Response status: #{response[:status]}"

  if response[:status] == 200
    puts "✅ Leader removal successful"
    result = JSON.parse(response[:body])
    if result['success']
      schedule_data = result['data']
      puts "   Leader removed: #{schedule_data['daily_leader'] ? 'Still assigned' : 'Successfully removed'}"
    end
  else
    puts "❌ Leader removal failed"
    puts "Response: #{response[:body]}"
  end
else
  puts "⚠️  Not enough schedules for leader removal test"
end

# Test 10: Test permission validation with non-leader user
puts "\n🔒 Test 10: Testing permission validation with non-leader user..."
user2_token = tokens[:user2]  # User2 is not the event leader

if schedules.length > 1
  schedule_to_test = schedules[1]

  # Try to assign leader as non-leader user (should fail)
  response = make_request("POST", "/api/v1/reading_schedules/#{schedule_to_test.id}/assign_leader?reading_event_id=#{event.id}", user2_token, {
    user_id: USERS[:user2][:id]
  })
  puts "Response status: #{response[:status]}"

  if response[:status] == 403  # Forbidden
    puts "✅ Permission validation correctly blocked non-leader user"
  else
    puts "❌ Permission validation failed - should be forbidden"
    puts "Response: #{response[:body]}"
  end
else
  puts "⚠️  Not enough schedules for permission validation test"
end

puts "\n🎉 Comprehensive reading schedule API testing completed!"