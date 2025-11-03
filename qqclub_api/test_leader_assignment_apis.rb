#!/usr/bin/env ruby

# Load Rails environment
require_relative 'config/environment'
require 'net/http'
require 'json'

puts "🚀 Testing leader assignment system APIs..."

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

# Set up test data
puts "\n📋 Setting up test data..."
event = ReadingEvent.find(6)  # Use existing event
schedules = event.reading_schedules.order(:day_number)

puts "✅ Using event: #{event.title} (ID: #{event.id})"
puts "✅ Found #{schedules.count} reading schedules"

# Generate tokens
tokens = {}
USERS.each do |key, user|
  tokens[key] = generate_token(user)
  puts "✅ Generated token for #{user[:nickname]} (ID: #{user[:id]})"
end

# Test 1: Get initial assignment statistics
puts "\n📊 Test 1: Getting initial assignment statistics..."
leader_token = tokens[:user1]  # Event leader

response = make_request("GET", "/api/v1/reading_events/#{event.id}/leader_assignments/statistics", leader_token)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Assignment statistics retrieval successful"
  result = JSON.parse(response[:body])
  if result['success']
    stats = result['data']
    puts "   Total schedules: #{stats['total_schedules']}"
    puts "   Assigned schedules: #{stats['assigned_schedules']}"
    puts "   Assignment rate: #{stats['assignment_rate']}%"
    puts "   Unique leaders: #{stats['unique_leaders']}"
    puts "   Content completion rate: #{stats['content_completion_rate']}%"
  end
else
  puts "❌ Assignment statistics retrieval failed"
  puts "Response: #{response[:body]}"
end

# Test 2: Test random assignment algorithm
puts "\n🎲 Test 2: Testing random assignment algorithm..."
response = make_request("POST", "/api/v1/reading_events/#{event.id}/leader_assignments/auto_assign", leader_token, {
  assignment_type: 'random'
})
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Random assignment successful"
  result = JSON.parse(response[:body])
  if result['success']
    data = result['data']
    puts "   Assignment type: #{data['assignment_type']}"
    puts "   Assigned count: #{data['assigned_count']}"
    puts "   Updated statistics:"
    puts "     Assignment rate: #{data['statistics']['assignment_rate']}%"
    puts "     Unique leaders: #{data['statistics']['unique_leaders']}"
  end
else
  puts "❌ Random assignment failed"
  puts "Response: #{response[:body]}"
end

# Test 3: Test balanced assignment algorithm
puts "\n⚖️  Test 3: Testing balanced assignment algorithm..."
response = make_request("POST", "/api/v1/reading_events/#{event.id}/leader_assignments/auto_assign", leader_token, {
  assignment_type: 'balanced'
})
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Balanced assignment successful"
  result = JSON.parse(response[:body])
  if result['success']
    data = result['data']
    puts "   Assignment type: #{data['assignment_type']}"
    puts "   Assigned count: #{data['assigned_count']}"
  end
else
  puts "❌ Balanced assignment failed"
  puts "Response: #{response[:body]}"
end

# Test 4: Test rotation assignment algorithm
puts "\n🔄 Test 4: Testing rotation assignment algorithm..."
response = make_request("POST", "/api/v1/reading_events/#{event.id}/leader_assignments/auto_assign", leader_token, {
  assignment_type: 'rotation'
})
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Rotation assignment successful"
  result = JSON.parse(response[:body])
  if result['success']
    data = result['data']
    puts "   Assignment type: #{data['assignment_type']}"
    puts "   Assigned count: #{data['assigned_count']}"
  end
else
  puts "❌ Rotation assignment failed"
  puts "Response: #{response[:body]}"
end

# Test 5: Check backup needed schedules
puts "\n🚨 Test 5: Checking backup needed schedules..."
response = make_request("GET", "/api/v1/reading_events/#{event.id}/leader_assignments/backup_needed", leader_token)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Backup needed schedules retrieval successful"
  result = JSON.parse(response[:body])
  if result['success']
    data = result['data']
    puts "   Total needing backup: #{data['total_needing_backup']}"
    puts "   Content deadline soon: #{data['content_deadline_soon']}"
    puts "   Flowers deadline soon: #{data['flowers_deadline_soon']}"

    if data['backup_schedules'].any?
      puts "   Backup schedules:"
      data['backup_schedules'].first(3).each_with_index do |schedule, index|
        puts "     #{index + 1}. Day #{schedule['schedule']['day_number']} - #{schedule['schedule']['date']}"
        puts "        Leader: #{schedule['leader'] ? schedule['leader']['nickname'] : 'None'}"
        puts "        Priority: #{schedule['backup_priority']}"
        puts "        Missing content: #{schedule['missing_content']}"
        puts "        Missing flowers: #{schedule['missing_flowers']}"
      end
    end
  end
else
  puts "❌ Backup needed schedules retrieval failed"
  puts "Response: #{response[:body]}"
end

# Test 6: Check leader permissions
puts "\n🔒 Test 6: Checking leader permissions..."
user2_token = tokens[:user2]  # Participant
schedule = schedules.first

response = make_request("GET", "/api/v1/reading_events/#{event.id}/leader_assignments/permissions?schedule_id=#{schedule.id}", user2_token)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Leader permissions check successful"
  result = JSON.parse(response[:body])
  if result['success']
    permissions = result['data']
    puts "   Can view: #{permissions['can_view']}"
    puts "   Can claim leadership: #{permissions['can_claim_leadership']}"
    puts "   Can be assigned: #{permissions['can_be_assigned']}"
    puts "   Can backup: #{permissions['can_backup']}"

    if permissions['permission_window']
      window = permissions['permission_window']
      puts "   Permission window:"
      puts "     Can publish content: #{window['can_publish_content']}"
      puts "     Can give flowers: #{window['can_give_flowers']}"
      puts "     Permission deadline: #{window['permission_deadline']}"
    end
  end
else
  puts "❌ Leader permissions check failed"
  puts "Response: #{response[:response_body]}"
end

# Test 7: Test claim leadership (if voluntary mode)
puts "\n✋ Test 7: Testing claim leadership..."
if event.leader_assignment_type == 'voluntary'
  response = make_request("POST", "/api/v1/reading_events/#{event.id}/leader_assignments/#{schedules.last.id}/claim_leadership", user2_token)
  puts "Response status: #{response[:status]}"

  if response[:status] == 200
    puts "✅ Claim leadership successful"
    result = JSON.parse(response[:body])
    if result['success']
      schedule_data = result['data']
      puts "   Schedule: Day #{schedule_data[:day_number]} - #{schedule_data[:date]}"
      puts "   Leader: #{schedule_data[:leader][:nickname]}"
    end
  else
    puts "❌ Claim leadership failed"
    puts "Response: #{response[:response_body]}"
  end
else
  puts "⚠️  Event is not in voluntary mode, skipping claim leadership test"
end

# Test 8: Test reassign leader
puts "\n🔄 Test 8: Testing reassign leader..."
response = make_request("POST", "/api/v1/reading_events/#{event.id}/leader_assignments/#{schedules.first.id}/reassign", leader_token, {
  new_leader_id: USERS[:user3][:id]
})
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Reassign leader successful"
  result = JSON.parse(response[:body])
  if result['success']
    data = result['data']
    puts "   Schedule: Day #{data[:schedule][:day_number]} - #{data[:schedule][:date]}"
    puts "   Old leader: #{data[:old_leader] ? data[:old_leader][:nickname] : 'None'}"
    puts "   New leader: #{data[:new_leader][:nickname]}"
  end
else
  puts "❌ Reassign leader failed"
  puts "Response: #{response[:response_body]}"
end

# Test 9: Test backup assignment
puts "\n🛠️ Test 9: Testing backup assignment..."
response = make_request("POST", "/api/v1/reading_events/#{event.id}/leader_assignments/#{schedules.second.id}/backup", leader_token, {
  backup_leader_id: USERS[:user2][:id]
})
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Backup assignment successful"
  result = JSON.parse(response[:body])
  if result['success']
    data = result['data']
    puts "   Schedule: Day #{data[:schedule][:day_number]} - #{data[:schedule][:date]}"
    puts "   Backup leader: #{data[:backup_leader][:nickname]}"
  end
else
  puts "❌ Backup assignment failed"
  puts "Response: #{response[:response_body]}"
end

# Test 10: Final statistics check
puts "\n📊 Test 10: Final statistics check..."
response = make_request("GET", "/api/v1/reading_events/#{event.id}/leader_assignments/statistics", leader_token)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Final statistics check successful"
  result = JSON.parse(response[:body])
  if result['success']
    stats = result['data']
    puts "   Final assignment rate: #{stats['assignment_rate']}%"
    puts "   Final unique leaders: #{stats['unique_leaders']}"
    puts "   Leader workload breakdown:"
    stats['leader_workload'].first(3).each_with_index do |workload, index|
      puts "     #{index + 1}. #{workload[:nickname]}: #{workload[:assigned_count]} schedules, #{workload[:content_completed]} content completed"
    end
  end
else
  puts "❌ Final statistics check failed"
  puts "Response: #{response[:response_body]}"
end

puts "\n🎉 Leader assignment system API testing completed!"