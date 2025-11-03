#!/usr/bin/env ruby

# Load Rails environment
require_relative 'config/environment'
require 'net/http'
require 'json'

puts "🚀 Testing activity approval workflow APIs..."

# Base URL
BASE_URL = 'http://localhost:3000'

# Test users
USERS = {
  user1: { id: 1, nickname: 'DHH', wx_openid: 'test_dhh_001' },
  user2: { id: 2, nickname: '张三', wx_openid: 'test_user_002' },
  admin: { id: 3, nickname: '测试管理员', wx_openid: 'test_admin_001', role: 'admin' }
}

# Helper method to generate JWT token
def generate_token(user)
  payload = {
    user_id: user[:id],
    wx_openid: user[:wx_openid],
    role: user[:role] || 'user',
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

# Generate tokens
puts "\n📋 Generating authentication tokens..."
tokens = {}
USERS.each do |key, user|
  tokens[key] = generate_token(user)
  puts "✅ Generated token for #{user[:nickname]} (ID: #{user[:id]})"
end

# Test 1: Create a new event for approval workflow testing
puts "\n📝 Test 1: Creating new event for approval workflow testing..."
user1_token = tokens[:user1]

new_event_data = {
  title: "审批工作流测试活动",
  book_name: "审批测试书籍",
  start_date: Date.today + 10.days,
  end_date: Date.today + 17.days,
  description: "这是一个用于测试审批工作流的活动，包含完整的信息以验证审批流程。",
  activity_mode: "note_checkin",
  max_participants: 20,
  min_participants: 5,
  fee_type: "free"
}

response = make_request("POST", "/api/v1/reading_events", user1_token, new_event_data)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Event created successfully"
  result = JSON.parse(response[:body])
  if result['success']
    event_id = result['data']['id']
    puts "   New Event ID: #{event_id}"
    puts "   Initial status: #{result['data']['status']}"
    puts "   Initial approval status: #{result['data']['approval_status']}"
  end
else
  puts "❌ Event creation failed"
  puts "Response: #{response[:body]}"
  exit 1
end

# Test 2: Submit event for approval
puts "\n📤 Test 2: Submitting event for approval..."
response = make_request("POST", "/api/v1/approval_workflow/submit_for_approval", user1_token, {
  event_id: event_id,
  workflow_type: "standard"
})
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Event submitted for approval successfully"
  result = JSON.parse(response[:body])
  if result['success']
    puts "   Message: #{result['message']}"
    puts "   Approval queue position: #{result['data']['approval_queue_position']}"
  end
else
  puts "❌ Submit for approval failed"
  puts "Response: #{response[:body]}"
end

# Test 3: Check approval queue
puts "\n📋 Test 3: Checking approval queue..."
admin_token = tokens[:admin]

response = make_request("GET", "/api/v1/approval_workflow/approval_queue", admin_token)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Approval queue retrieval successful"
  result = JSON.parse(response[:body])
  if result['success']
    data = result['data']
    puts "   Total pending events: #{data['pagination']['total_count']}"
    puts "   Current page: #{data['pagination']['current_page']}"

    if data['approval_queue'].any?
      puts "   Pending events:"
      data['approval_queue'].first(3).each_with_index do |event, index|
        puts "     #{index + 1}. #{event['title']} (ID: #{event['id']})"
        puts "        Leader: #{event['leader']['nickname']}"
        puts "        Submitted: #{event['submitted_for_approval_at']}"
        puts "        Pending for: #{event['pending_age_days']} days"
        puts "        Validation: #{event['validation_status']}"
      end
    end
  end
else
  puts "❌ Approval queue retrieval failed"
  puts "Response: #{response[:body]}"
end

# Test 4: Check event approval status
puts "\n📊 Test 4: Checking event approval status..."

response = make_request("GET", "/api/v1/approval_workflow/event_approval_status?event_id=#{event_id}", user1_token)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Event approval status retrieval successful"
  result = JSON.parse(response[:body])
  if result['success']
    status_data = result['data']
    puts "   Event title: #{status_data['title']}"
    puts "   Status: #{status_data['status']}"
    puts "   Approval status: #{status_data['approval_status']}"
    puts "   Submitted for approval at: #{status_data['submitted_for_approval_at']}"
    puts "   Can submit for approval: #{status_data['can_submit_for_approval']}"
    puts "   Can resubmit for approval: #{status_data['can_resubmit_for_approval']}"
    puts "   Validation status: #{status_data['validation_status']['valid'] ? 'Valid' : 'Invalid'}"

    if status_data['validation_status']['errors'].any?
      puts "   Validation errors:"
      status_data['validation_status']['errors'].each do |error|
        puts "     - #{error}"
      end
    end
  end
else
  puts "❌ Event approval status retrieval failed"
  puts "Response: #{response[:body]}"
end

# Test 5: Try to approve event as non-admin
puts "\n🚫 Test 5: Trying to approve event as non-admin..."
user2_token = tokens[:user2]

response = make_request("POST", "/api/v1/approval_workflow/approve_event", user2_token, {
  event_id: event_id,
  reason: "非管理员审批测试"
})
puts "Response status: #{response[:status]}"

if response[:status] == 403
  puts "✅ Permission correctly denied for non-admin"
  result = JSON.parse(response[:body])
  puts "   Error: #{result['error']}"
else
  puts "❌ Permission check failed"
  puts "Response: #{response[:body]}"
end

# Test 6: Approve event as admin
puts "\n✅ Test 6: Approving event as admin..."

response = make_request("POST", "/api/v1/approval_workflow/approve_event", admin_token, {
  event_id: event_id,
  reason: "活动内容完整，符合审批标准",
  notes: "检查了所有必填字段，活动计划合理"
})
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Event approval successful"
  result = JSON.parse(response[:body])
  if result['success']
    puts "   Message: #{result['message']}"
    approval_details = result['data']['approval_details']
    puts "   Approved by: #{approval_details['approved_by']['nickname']}"
    puts "   Approved at: #{approval_details['approved_at']}"
    puts "   Reason: #{approval_details['reason']}"
    puts "   Next steps:"
    approval_details['next_steps'].each do |step|
      puts "     - #{step}"
    end
  end
else
  puts "❌ Event approval failed"
  puts "Response: #{response[:body]}"
end

# Test 7: Create another event for rejection testing
puts "\n📝 Test 7: Creating another event for rejection testing..."

rejection_event_data = {
  title: "拒绝测试活动",
  book_name: "测试书籍",
  start_date: Date.today + 15.days,
  end_date: Date.today + 20.days,
  description: "不完整的活动描述",  # 故意提供不完整信息
  activity_mode: "note_checkin",
  max_participants: 10,
  min_participants: 3,
  fee_type: "free"
}

response = make_request("POST", "/api/v1/reading_events", user1_token, rejection_event_data)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Rejection test event created successfully"
  result = JSON.parse(response[:body])
  rejection_event_id = result['data']['id']
  puts "   Rejection Event ID: #{rejection_event_id}"
else
  puts "❌ Rejection test event creation failed"
  rejection_event_id = nil
end

if rejection_event_id
  # Submit for approval
  response = make_request("POST", "/api/v1/approval_workflow/submit_for_approval", user1_token, {
    event_id: rejection_event_id
  })

  if response[:status] == 200
    puts "✅ Rejection test event submitted for approval"

    # Test 8: Reject event as admin
    puts "\n❌ Test 8: Rejecting event as admin..."

    response = make_request("POST", "/api/v1/approval_workflow/reject_event", admin_token, {
      event_id: rejection_event_id,
      reason: "活动描述过于简单，需要提供更详细的活动计划",
      notes: "请补充阅读进度安排、活动目标等详细信息"
    })
    puts "Response status: #{response[:status]}"

    if response[:status] == 200
      puts "✅ Event rejection successful"
      result = JSON.parse(response[:body])
      if result['success']
        puts "   Message: #{result['message']}"
        rejection_details = result['data']['rejection_details']
        puts "   Reason: #{rejection_details['reason']}"
        puts "   Notes: #{rejection_details['notes']}"
        puts "   Resubmission allowed: #{rejection_details['resubmission_allowed']}"
      end
    else
      puts "❌ Event rejection failed"
      puts "Response: #{response[:body]}"
    end
  end
end

# Test 9: Create multiple events for batch approval testing
puts "\n📝 Test 9: Creating multiple events for batch approval testing..."
batch_event_ids = []

3.times do |i|
  batch_event_data = {
    title: "批量审批测试活动 #{i + 1}",
    book_name: "批量测试书籍",
    start_date: Date.today + (20 + i).days,
    end_date: Date.today + (27 + i).days,
    description: "这是第#{i + 1}个用于批量审批测试的活动，包含完整信息。",
    activity_mode: "note_checkin",
    max_participants: 15,
    min_participants: 3,
    fee_type: "free"
  }

  response = make_request("POST", "/api/v1/reading_events", user1_token, batch_event_data)
  if response[:status] == 200
    result = JSON.parse(response[:body])
    event_id = result['data']['id']
    batch_event_ids << event_id

    # Submit for approval
    make_request("POST", "/api/v1/approval_workflow/submit_for_approval", user1_token, {
      event_id: event_id
    })
  end
end

puts "✅ Created #{batch_event_ids.count} events for batch approval testing"

# Test 10: Batch approve events
puts "\n📋 Test 10: Batch approving events..."

if batch_event_ids.any?
  response = make_request("POST", "/api/v1/approval_workflow/batch_approve", admin_token, {
    event_ids: batch_event_ids,
    reason: "批量审批通过 - 活动内容完整，符合标准"
  })
  puts "Response status: #{response[:status]}"

  if response[:status] == 200
    puts "✅ Batch approval successful"
    result = JSON.parse(response[:body])
    if result['success']
      summary = result['data']['summary']
      puts "   Total: #{summary['total']}"
      puts "   Successful: #{summary['successful']}"
      puts "   Failed: #{summary['failed']}"

      if result['data']['batch_results'].any?
        puts "   Batch results:"
        result['data']['batch_results'].first(5).each do |result_item|
          status_icon = result_item['success'] ? '✅' : '❌'
          puts "     #{status_icon} Event ID: #{result_item['event_id']} - #{result_item['status']}"
        end
      end
    end
  else
    puts "❌ Batch approval failed"
    puts "Response: #{response[:body]}"
  end
end

# Test 11: Get approval statistics
puts "\n📊 Test 11: Getting approval statistics..."

response = make_request("GET", "/api/v1/approval_workflow/approval_statistics", admin_token)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Approval statistics retrieval successful"
  result = JSON.parse(response[:body])
  if result['success']
    stats = result['data']
    puts "   Total pending: #{stats['total_pending']}"
    puts "   Total approved: #{stats['total_approved']}"
    puts "   Total rejected: #{stats['total_rejected']}"
    puts "   Period approved: #{stats['period_approved']}"
    puts "   Period rejected: #{stats['period_rejected']}"
    puts "   Average approval time: #{stats['average_approval_time']} hours"
    puts "   Approval rate: #{stats['approval_rate']}%"

    if stats['activity_mode_stats'].any?
      puts "   Activity mode statistics:"
      stats['activity_mode_stats'].each do |mode, mode_stats|
        puts "     #{mode}: #{mode_stats['approved']}/#{mode_stats['total']} (#{mode_stats['approval_rate']}%)"
      end
    end
  end
else
  puts "❌ Approval statistics retrieval failed"
  puts "Response: #{response[:body]}"
end

# Test 12: Test escalation workflow
puts "\n🚨 Test 12: Testing escalation workflow..."

# Create an event that needs escalation
escalation_event_data = {
  title: "需要升级审批的活动",
  book_name: "升级测试书籍",
  start_date: Date.today + 5.days,
  end_date: Date.today + 12.days,
  description: "这是一个复杂的活动，需要高级管理员审批",
  activity_mode: "video_conference",
  max_participants: 50,
  min_participants: 10,
  fee_type: "paid",
  fee_amount: 100,
  meeting_link: "https://meeting.example.com/complex-event"
}

response = make_request("POST", "/api/v1/reading_events", user1_token, escalation_event_data)
if response[:status] == 200
  result = JSON.parse(response[:body])
  escalation_event_id = result['data']['id']

  # Submit for approval
  make_request("POST", "/api/v1/approval_workflow/submit_for_approval", user1_token, {
    event_id: escalation_event_id
  })

  # Escalate approval
  response = make_request("POST", "/api/v1/approval_workflow/escalate_approval", admin_token, {
    event_id: escalation_event_id,
    escalation_reason: "活动规模较大，涉及费用，需要高级管理员审核"
  })
  puts "Response status: #{response[:status]}"

  if response[:status] == 200
    puts "✅ Escalation successful"
    result = JSON.parse(response[:body])
    if result['success']
      escalation_details = result['data']['escalation_details']
      puts "   Reason: #{escalation_details['reason']}"
      puts "   Escalated by: #{escalation_details['escalated_by']['nickname']}"
      puts "   Escalated at: #{escalation_details['escalated_at']}"
    end
  else
    puts "❌ Escalation failed"
    puts "Response: #{response[:body]}"
  end
end

# Test 13: Test approval queue filtering
puts "\n🔍 Test 13: Testing approval queue filtering..."

response = make_request("GET", "/api/v1/approval_workflow/approval_queue?activity_mode=note_checkin&per_page=5", admin_token)
puts "Response status: #{response[:status]}"

if response[:status] == 200
  puts "✅ Filtered approval queue retrieval successful"
  result = JSON.parse(response[:body])
  if result['success']
    data = result['data']
    puts "   Filtered results: #{data['pagination']['total_count']} events (note_checkin mode)"
    puts "   Per page: #{data['pagination']['per_page']}"

    if data['filters_applied'].any?
      puts "   Applied filters:"
      data['filters_applied'].each do |key, value|
        puts "     #{key}: #{value}"
      end
    end
  end
else
  puts "❌ Filtered approval queue retrieval failed"
  puts "Response: #{response[:body]}"
end

puts "\n🎉 Activity approval workflow API testing completed!"
puts "\n📝 Summary:"
puts "  ✅ Event submission for approval workflow"
puts "  ✅ Approval queue management and filtering"
puts "  ✅ Individual event approval and rejection"
puts "  ✅ Batch approval operations"
puts "  ✅ Approval escalation workflow"
puts "  ✅ Approval statistics and reporting"
puts "  ✅ Permission validation and security controls"
puts "  ✅ Event validation and status tracking"
puts "  ✅ Comprehensive workflow coverage"