#!/usr/bin/env ruby

# Load Rails environment
require_relative 'config/environment'
require 'net/http'
require 'json'

puts "🚀 Starting comprehensive enrollment API testing..."

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

# Test 1: Create or find test event
puts "\n📋 Test 1: Setting up test event..."
event = ReadingEvent.where(title: "API测试报名活动").first

if event.nil?
  puts "Creating new test event..."
  event = ReadingEvent.create!(
    title: "API测试报名活动",
    book_name: "API测试书籍",
    start_date: Date.today + 3.days,
    end_date: Date.today + 10.days,
    description: "用于API测试的报名活动",
    leader: User.find(USERS[:user1][:id]),
    status: :enrolling,
    approval_status: :approved,
    max_participants: 5,
    min_participants: 1
  )
  puts "✅ Created test event: #{event.id}"
else
  puts "✅ Found existing test event: #{event.id}"
end

# Test 2: Generate tokens for different users
puts "\n🔑 Test 2: Generating authentication tokens..."
tokens = {}
USERS.each do |key, user|
  tokens[key] = generate_token(user)
  puts "✅ Generated token for #{user[:nickname]} (ID: #{user[:id]})"
end

# Test 3: Test enrollment creation (user2 enrolls in event)
puts "\n📝 Test 3: Testing enrollment creation..."
user2_token = tokens[:user2]

# Check if user2 is already enrolled
existing_enrollment = EventEnrollment.find_by(user_id: USERS[:user2][:id], reading_event_id: event.id)
if existing_enrollment
  puts "⚠️  User2 already enrolled, cleaning up..."
  existing_enrollment.destroy!
end

response = make_request('POST', '/api/v1/event_enrollments', user2_token, {
  reading_event_id: event.id,
  enrollment_type: 'participant'
})

puts "Response status: #{response[:status]}"
puts "Response body: #{response[:body]}"

if response[:status] == 200 || response[:status] == 201
  puts "✅ Enrollment creation successful"
  result = JSON.parse(response[:body])
  if result['success']
    enrollment_data = result['data']
    puts "   Enrollment ID: #{enrollment_data['id']}"
    puts "   Enrollment type: #{enrollment_data['enrollment_type']}"
    puts "   Status: #{enrollment_data['status']}"
  end
else
  puts "❌ Enrollment creation failed"
end

# Test 4: Test enrollment list (event leader view)
puts "\n📊 Test 4: Testing enrollment list (leader view)..."
leader_token = tokens[:user1]  # User1 is the event leader

response = make_request("GET", "/api/v1/reading_events/#{event.id}/enrollments", leader_token)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Enrollment list retrieval successful"
  result = JSON.parse(response[:body])
  if result['success']
    enrollments = result['data']
    if enrollments
      puts "   Total enrollments: #{enrollments.length}"
      enrollments.each_with_index do |enrollment, index|
        puts "   #{index + 1}. #{enrollment['user']['nickname']} - #{enrollment['status']}"
      end
    else
      puts "   No enrollments found"
    end
  end
else
  puts "❌ Enrollment list retrieval failed"
end

# Test 5: Test enrollment statistics
puts "\n📈 Test 5: Testing enrollment statistics..."
response = make_request("GET", "/api/v1/reading_events/#{event.id}/enrollments/statistics", leader_token)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Statistics retrieval successful"
  result = JSON.parse(response[:body])
  if result['success']
    stats = result['data']
    puts "   Total enrollments: #{stats['total_enrollments']}"
    puts "   Active enrollments: #{stats['active_enrollments']}"
    puts "   Participants count: #{stats['participants_count']}"
    puts "   Observers count: #{stats['observers_count']}"
  end
else
  puts "❌ Statistics retrieval failed"
end

# Test 6: Test enrollment details
puts "\n🔍 Test 6: Testing enrollment details..."
enrollment = EventEnrollment.find_by(user_id: USERS[:user2][:id], reading_event_id: event.id)

if enrollment
  response = make_request("GET", "/api/v1/event_enrollments/#{enrollment.id}", user2_token)
  puts "Response status: #{response[:status]}"

  if response[:status] == 200
    puts "✅ Enrollment details retrieval successful"
    result = JSON.parse(response[:body])
    if result['success']
      enrollment_data = result['data']
      puts "   Enrollment: #{enrollment_data['user']['nickname']} - #{enrollment_data['status']}"
      puts "   Can cancel: #{enrollment_data['permissions']['can_cancel']}"
      puts "   Can check in: #{enrollment_data['permissions']['can_check_in']}"
    end
  else
    puts "❌ Enrollment details retrieval failed"
  end
else
  puts "⚠️  No enrollment found for details test"
end

# Test 7: Test enrollment cancellation
puts "\n❌ Test 7: Testing enrollment cancellation..."
if enrollment
  response = make_request("POST", "/api/v1/event_enrollments/#{enrollment.id}/cancel", user2_token)
  puts "Response status: #{response[:status]}"

  if response[:status] == 200
    puts "✅ Enrollment cancellation successful"
    result = JSON.parse(response[:body])
    if result['success']
      puts "   Enrollment status: #{result['data']['status']}"
    end
  else
    puts "❌ Enrollment cancellation failed"
    puts "Response: #{response[:body]}"
  end
else
  puts "⚠️  No enrollment found for cancellation test"
end

# Test 8: Test duplicate enrollment prevention
puts "\n🚫 Test 8: Testing duplicate enrollment prevention..."
# User1 (the leader) tries to enroll in their own event
response = make_request('POST', '/api/v1/event_enrollments', tokens[:user1], {
  reading_event_id: event.id,
  enrollment_type: 'participant'
})

puts "Response status: #{response[:status]}"
if response[:status] == 422  # Unprocessable Entity
  puts "✅ Duplicate enrollment correctly prevented"
else
  puts "❌ Duplicate enrollment prevention failed"
end

puts "\n🎉 Comprehensive enrollment API testing completed!"