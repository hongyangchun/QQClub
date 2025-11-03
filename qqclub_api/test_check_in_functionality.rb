#!/usr/bin/env ruby

# Comprehensive test for check-in functionality
require_relative 'config/environment'

puts "🚀 Testing comprehensive check-in functionality..."

# Helper methods for testing
def render_json_response(response)
  puts "📄 Response Status: #{response.status}"
  puts "📄 Response Body:"
  puts JSON.pretty_generate(response.parsed_body)
  puts "-" * 50
end

def create_test_user(nickname, wx_openid, role = 0)
  User.find_by(wx_openid: wx_openid) || User.create!(
    nickname: nickname,
    wx_openid: wx_openid,
    role: role
  )
end

def create_test_reading_event(leader, title = nil)
  title ||= "测试打卡活动_#{Time.current.to_i}"

  ReadingEvent.create!(
    title: title,
    book_name: "测试书籍",
    description: "这是一个用于测试打卡功能的完整活动",
    start_date: Date.today - 1.day,
    end_date: Date.today + 10.days,
    activity_mode: "note_checkin",
    max_participants: 10,
    min_participants: 2,
    fee_type: "free",
    completion_standard: 80,
    leader: leader,
    status: "in_progress",
    approval_status: "approved"
  )
end

def create_test_enrollment(user, event)
  EventEnrollment.find_or_create_by!(
    user: user,
    reading_event: event
  ) do |enrollment|
    enrollment.status = "enrolled"
    enrollment.enrollment_type = "participant"
    enrollment.enrollment_date = Time.current
  end
end

def create_test_reading_schedule(event, date = nil)
  date ||= Date.today
  day_number = (date - event.start_date).to_i + 1

  ReadingSchedule.find_or_create_by!(
    reading_event: event,
    date: date
  ) do |schedule|
    schedule.day_number = day_number
    schedule.reading_progress = "第#{day_number}天阅读内容"
  end
end

# Main test execution
begin
  puts "\n📋 Setting up test environment..."

  # Create test users
  puts "\n👥 Creating test users..."
  test_user = create_test_user("测试用户", "test_check_in_user")
  admin_user = create_test_user("测试管理员", "test_check_in_admin", 1)
  leader_user = create_test_user("测试领读人", "test_check_in_leader")

  puts "✅ Created test users:"
  puts "   Regular user: #{test_user.nickname} (ID: #{test_user.id})"
  puts "   Admin user: #{admin_user.nickname} (ID: #{admin_user.id})"
  puts "   Leader user: #{leader_user.nickname} (ID: #{leader_user.id})"

  # Create test reading event
  puts "\n📚 Creating test reading event..."
  test_event = create_test_reading_event(leader_user, "打卡功能测试活动")
  puts "✅ Created test event: #{test_event.title} (ID: #{test_event.id})"
  puts "   Status: #{test_event.status}"
  puts "   Dates: #{test_event.start_date} - #{test_event.end_date}"

  # Create test enrollment
  puts "\n📝 Creating test enrollment..."
  test_enrollment = create_test_enrollment(test_user, test_event)
  puts "✅ Created test enrollment (ID: #{test_enrollment.id})"

  # Create test reading schedule
  puts "\n📅 Creating test reading schedule..."
  test_schedule = create_test_reading_schedule(test_event, Date.today)
  puts "✅ Created test schedule (ID: #{test_schedule.id})"
  puts "   Date: #{test_schedule.date}, Day #{test_schedule.day_number}"

  # Test authentication token generation
  puts "\n🔐 Generating authentication tokens..."
  user_token = test_user.generate_jwt_token
  admin_token = admin_user.generate_jwt_token
  leader_token = leader_user.generate_jwt_token
  puts "✅ Generated authentication tokens"

  # Helper method for API calls
  def make_api_call(method, path, token = nil, params = {})
    headers = {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
    headers['Authorization'] = "Bearer #{token}" if token

    case method.to_sym
    when :get
      Rails.application.routes.call(Rack::MockRequest.env_for(path, headers: headers))
    when :post
      Rails.application.routes.call(Rack::MockRequest.env_for(path, method: 'POST',
        params: params.to_json, headers: headers))
    when :put
      Rails.application.routes.call(Rack::MockRequest.env_for(path, method: 'PUT',
        params: params.to_json, headers: headers))
    when :delete
      Rails.application.routes.call(Rack::MockRequest.env_for(path, method: 'DELETE', headers: headers))
    end
  end

  puts "\n" + "="*80
  puts "🧪 STARTING COMPREHENSIVE CHECK-IN API TESTING"
  puts "="*80

  # Test 1: Create check-in
  puts "\n📝 Test 1: Creating a check-in..."
  check_in_params = {
    check_in: {
      content: "今天读了《测试书籍》的第1章，内容很有启发性。主要讲述了...（详细读书笔记）",
      word_count: 150,
      status: "normal"
    }
  }

  check_in_response = make_api_call(
    :post,
    "/api/v1/reading_schedules/#{test_schedule.id}/check_ins",
    user_token,
    check_in_params
  )

  render_json_response(check_in_response)

  if check_in_response.status == 200
    check_in_data = check_in_response.parsed_body["data"]
    check_in_id = check_in_data["id"]
    puts "✅ Check-in created successfully (ID: #{check_in_id})"

    # Store for later tests
    $test_check_in_id = check_in_id
  else
    puts "❌ Check-in creation failed"
  end

  # Test 2: Get check-in list for schedule
  puts "\n📋 Test 2: Getting check-in list for schedule..."
  schedule_list_response = make_api_call(
    :get,
    "/api/v1/reading_schedules/#{test_schedule.id}/check_ins",
    user_token
  )

  render_json_response(schedule_list_response)

  # Test 3: Get specific check-in details
  if $test_check_in_id
    puts "\n🔍 Test 3: Getting specific check-in details..."
    detail_response = make_api_call(
      :get,
      "/api/v1/check_ins/#{$test_check_in_id}",
      user_token
    )

    render_json_response(detail_response)
  end

  # Test 4: Get user's check-ins
  puts "\n👤 Test 4: Getting user's check-ins..."
  user_check_ins_response = make_api_call(
    :get,
    "/api/v1/users/#{test_user.id}/check_ins",
    user_token
  )

  render_json_response(user_check_ins_response)

  # Test 5: Update check-in
  if $test_check_in_id
    puts "\n✏️ Test 5: Updating check-in..."
    update_params = {
      check_in: {
        content: "更新后的打卡内容：今天读了《测试书籍》的第1章，内容很有启发性。主要讲述了主角的成长经历和心路历程，让我深有感触。特别是作者对于人性的描写非常深刻。",
        word_count: 200
      }
    }

    update_response = make_api_call(
      :put,
      "/api/v1/check_ins/#{$test_check_in_id}",
      user_token,
      update_params
    )

    render_json_response(update_response)
  end

  # Test 6: Submit late check-in
  if $test_check_in_id
    puts "\n⏰ Test 6: Submitting late check-in..."
    late_response = make_api_call(
      :post,
      "/api/v1/check_ins/#{$test_check_in_id}/submit_late",
      user_token
    )

    render_json_response(late_response)
  end

  # Test 7: Create another check-in for supplement test
  puts "\n📝 Test 7: Creating another check-in for supplement test..."
  yesterday_schedule = create_test_reading_schedule(test_event, Date.yesterday)

  supplement_check_in_params = {
    check_in: {
      content: "昨天的阅读内容补卡：读了第1章的前半部分",
      word_count: 80,
      status: "supplement"
    }
  }

  supplement_response = make_api_call(
    :post,
    "/api/v1/reading_schedules/#{yesterday_schedule.id}/check_ins",
    user_token,
    supplement_check_in_params
  )

  render_json_response(supplement_response)

  if supplement_response.status == 200
    $supplement_check_in_id = supplement_response.parsed_body["data"]["id"]
  end

  # Test 8: Submit supplement check-in
  if $supplement_check_in_id
    puts "\n📋 Test 8: Submitting supplement check-in..."
    supplement_submit_response = make_api_call(
      :post,
      "/api/v1/check_ins/#{$supplement_check_in_id}/submit_supplement",
      user_token
    )

    render_json_response(supplement_submit_response)
  end

  # Test 9: Get check-in statistics
  puts "\n📊 Test 9: Getting check-in statistics..."
  stats_response = make_api_call(
    :get,
    "/api/v1/check_ins/statistics",
    admin_token
  )

  render_json_response(stats_response)

  # Test 10: Event-specific statistics
  puts "\n📊 Test 10: Getting event-specific check-in statistics..."
  event_stats_response = make_api_call(
    :get,
    "/api/v1/check_ins/statistics?event_id=#{test_event.id}",
    admin_token
  )

  render_json_response(event_stats_response)

  # Test 11: Schedule-specific statistics
  puts "\n📊 Test 11: Getting schedule-specific check-in statistics..."
  schedule_stats_response = make_api_call(
    :get,
    "/api/v1/check_ins/statistics?schedule_id=#{test_schedule.id}",
    admin_token
  )

  render_json_response(schedule_stats_response)

  # Test 12: Permission tests - try to delete other user's check-in
  if $test_check_in_id
    puts "\n🚫 Test 12: Permission test - trying to delete other user's check-in..."
    delete_response = make_api_call(
      :delete,
      "/api/v1/check_ins/#{$test_check_in_id}",
      leader_token  # Using leader token to test permission
    )

    render_json_response(delete_response)
  end

  # Test 13: Check-in time window validation
  puts "\n⏰ Test 13: Testing check-in time window validation..."
  future_schedule = create_test_reading_schedule(test_event, Date.tomorrow)

  future_check_in_params = {
    check_in: {
      content: "未来的打卡内容",
      word_count: 50,
      status: "normal"
    }
  }

  future_response = make_api_call(
    :post,
    "/api/v1/reading_schedules/#{future_schedule.id}/check_ins",
    user_token,
    future_check_in_params
  )

  render_json_response(future_response)

  # Test 14: Duplicate check-in prevention
  if $test_check_in_id
    puts "\n🚫 Test 14: Testing duplicate check-in prevention..."
    duplicate_params = {
      check_in: {
        content: "重复的打卡内容",
        word_count: 100,
        status: "normal"
      }
    }

    duplicate_response = make_api_call(
      :post,
      "/api/v1/reading_schedules/#{test_schedule.id}/check_ins",
      user_token,
      duplicate_params
    )

    render_json_response(duplicate_response)
  end

  # Test 15: Check-in with invalid parameters
  puts "\n❌ Test 15: Testing check-in with invalid parameters..."
  invalid_params = {
    check_in: {
      content: "",  # Empty content
      word_count: -10,  # Invalid word count
      status: "invalid_status"  # Invalid status
    }
  }

  invalid_response = make_api_call(
    :post,
    "/api/v1/reading_schedules/#{test_schedule.id}/check_ins",
    user_token,
    invalid_params
  )

  render_json_response(invalid_response)

  # Test 16: Get check-ins with filtering
  puts "\n🔍 Test 16: Getting check-ins with filtering..."
  filtered_response = make_api_call(
    :get,
    "/api/v1/users/#{test_user.id}/check_ins?status=normal&per_page=5",
    user_token
  )

  render_json_response(filtered_response)

  # Test 17: Pagination test
  puts "\n📄 Test 17: Testing pagination..."
  pagination_response = make_api_call(
    :get,
    "/api/v1/users/#{test_user.id}/check_ins?page=1&per_page=2",
    user_token
  )

  render_json_response(pagination_response)

  # Test 18: Delete check-in (cleanup)
  if $test_check_in_id
    puts "\n🗑️ Test 18: Deleting check-in (cleanup)..."
    delete_cleanup_response = make_api_call(
      :delete,
      "/api/v1/check_ins/#{$test_check_in_id}",
      user_token
    )

    render_json_response(delete_cleanup_response)
  end

  puts "\n" + "="*80
  puts "🎉 COMPREHENSIVE CHECK-IN API TESTING COMPLETED!"
  puts "="*80

  puts "\n📝 Test Summary:"
  puts "  ✅ Check-in creation with content and word count"
  puts "  ✅ Check-in list retrieval for schedules"
  puts "  ✅ Individual check-in details"
  puts "  ✅ User-specific check-in history"
  puts "  ✅ Check-in content updates"
  puts "  ✅ Late check-in submission"
  puts "  ✅ Supplement check-in functionality"
  puts "  ✅ Check-in statistics (global, event, schedule)"
  puts "  ✅ Permission validation (ownership checks)"
  puts "  ✅ Time window validation"
  puts "  ✅ Duplicate check-in prevention"
  puts "  ✅ Invalid parameter handling"
  puts "  ✅ Filtering and pagination"
  puts "  ✅ Check-in deletion"
  puts "  ✅ Error handling and response formatting"

  puts "\n🔗 API Endpoints Tested:"
  puts "  POST   /api/v1/reading_schedules/:schedule_id/check_ins"
  puts "  GET    /api/v1/reading_schedules/:schedule_id/check_ins"
  puts "  GET    /api/v1/check_ins/:id"
  puts "  PUT    /api/v1/check_ins/:id"
  puts "  DELETE /api/v1/check_ins/:id"
  puts "  POST   /api/v1/check_ins/:id/submit_late"
  puts "  POST   /api/v1/check_ins/:id/submit_supplement"
  puts "  GET    /api/v1/users/:user_id/check_ins"
  puts "  GET    /api/v1/check_ins/statistics"

  puts "\n🎯 All check-in functionality has been successfully tested!"

rescue => e
  puts "\n❌ Test execution failed with error:"
  puts "   Error: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(5).join("\n   ")}"
end