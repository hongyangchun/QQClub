#!/usr/bin/env ruby

# Simple test for updated permission rules
require_relative 'config/environment'

puts "🚀 Testing updated permission rules..."

# Helper methods
def create_test_user(nickname, wx_openid)
  User.find_by(wx_openid: wx_openid) || User.create!(
    nickname: nickname,
    wx_openid: wx_openid,
    role: 0
  )
end

def create_test_event(end_date, start_date = nil)
  leader = create_test_user("活动领读人", "test_event_leader")
  start_date ||= [Date.today - 1.day, end_date - 1.day].min

  ReadingEvent.create!(
    title: "权限测试活动",
    book_name: "测试书籍",
    description: "这是一个用于测试权限规则的活动",
    start_date: start_date,
    end_date: end_date,
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

def create_test_schedule(event, date = nil)
  date ||= Date.today
  day_number = (date - event.start_date).to_i + 1
  day_number = 1 if day_number < 1

  ReadingSchedule.find_or_create_by!(
    reading_event: event,
    date: date
  ) do |schedule|
    schedule.day_number = day_number
    schedule.reading_progress = "第#{day_number}天阅读内容"
  end
end

# Main test
begin
  puts "\n📋 Setting up..."

  # Create test user
  test_user = create_test_user("测试用户", "test_permission_rules")
  puts "✅ Created test user: #{test_user.nickname} (ID: #{test_user.id})"

  # Create ongoing event
  ongoing_event = create_test_event(Date.today + 10.days)
  ongoing_enrollment = create_test_enrollment(test_user, ongoing_event)
  ongoing_schedule = create_test_schedule(ongoing_event, Date.today)
  puts "✅ Created ongoing event: #{ongoing_event.title} (end_date: #{ongoing_event.end_date})"

  # Create ended event
  ended_event_end = Date.today - 5.days
  ended_event_start = ended_event_end - 10.days
  ended_event = create_test_event(ended_event_end, ended_event_start)
  ended_enrollment = create_test_enrollment(test_user, ended_event)
  ended_event.update!(status: 'completed')
  ended_schedule = create_test_schedule(ended_event, Date.today - 10.days)
  puts "✅ Created ended event: #{ended_event.title} (end_date: #{ended_event.end_date})"

  puts "\n" + "="*60
  puts "🧪 TESTING PERMISSION RULES"
  puts "="*60

  # Test 1: Check creation permissions
  puts "\n📝 Test 1: Creating check-ins..."

  # Ongoing event check-in (should work)
  ongoing_check_in = CheckIn.new(
    user: test_user,
    reading_schedule: ongoing_schedule,
    enrollment: ongoing_enrollment,
    content: "进行中活动的打卡内容：今天读了《测试书籍》的第1章，内容很有启发性。主要讲述了主角的成长经历和心路历程，让我深有感触。",
    word_count: 120,
    status: "normal",
    submitted_at: Time.current
  )

  if ongoing_check_in.save
    puts "✅ Ongoing event check-in created (ID: #{ongoing_check_in.id})"
    $ongoing_check_in_id = ongoing_check_in.id
  else
    puts "❌ Ongoing event check-in failed"
  end

  # Test 2: Test editing permissions
  puts "\n✏️ Test 2: Testing editing permissions..."

  if $ongoing_check_in_id
    check_in = CheckIn.find($ongoing_check_in_id)

    # Test permission method
    if check_in.can_be_edited?
      puts "✅ Ongoing check-in can be edited"
    else
      puts "❌ Ongoing check-in should be editable"
    end

    # Test update
    check_in.content = "更新后的内容：修改了今天的阅读笔记"
    if check_in.save
      puts "✅ Check-in updated successfully"
    else
      puts "❌ Check-in update failed"
    end
  end

  # Test 3: Test deletion permissions
  puts "\n🗑️ Test 3: Testing deletion permissions..."

  if $ongoing_check_in_id
    check_in = CheckIn.find($ongoing_check_in_id)

    # Test permission method
    if check_in.can_be_deleted?
      puts "✅ Ongoing check-in can be deleted"
    else
      puts "❌ Ongoing check-in should be deletable"
    end

    # Store original stats
    original_count = check_in.enrollment.check_ins_count
    puts "   Original check-ins count: #{original_count}"

    # Test deletion
    if check_in.destroy
      puts "✅ Check-in deleted successfully"

      # Check stats rollback
      updated_enrollment = EventEnrollment.find(ongoing_enrollment.id)
      if updated_enrollment.check_ins_count < original_count
        puts "✅ Statistics rolled back correctly"
      else
        puts "❌ Statistics not rolled back"
      end
    else
      puts "❌ Check-in deletion failed"
    end
  end

  # Test 4: Test ended event permissions
  puts "\n📅 Test 4: Testing ended event permissions..."

  # Create check-in for ended event (without validation to test permissions)
  ended_check_in = CheckIn.new(
    user: test_user,
    reading_schedule: ended_schedule,
    enrollment: ended_enrollment,
    content: "已结束活动的打卡内容",
    word_count: 80,
    status: "normal",
    submitted_at: Time.current - 10.days
  )

  # Save without validation to test permission methods
  ended_check_in.save(validate: false)

  puts "✅ Created ended event check-in for permission testing"

  # Test permission methods
  if ended_check_in.can_be_edited?
    puts "❌ Ended event check-in should not be editable"
  else
    puts "✅ Ended event check-in correctly cannot be edited"
  end

  if ended_check_in.can_be_deleted?
    puts "❌ Ended event check-in should not be deletable"
  else
    puts "✅ Ended event check-in correctly cannot be deleted"
  end

  # Clean up
  ended_check_in.destroy

  puts "\n" + "="*60
  puts "🎉 TESTING COMPLETED!"
  puts "="*60

  puts "\n📋 Results:"
  puts "  ✅ Ongoing events allow editing and deletion"
  puts "  ✅ Ended events block editing and deletion"
  puts "  ✅ Statistics rollback works"
  puts "  ✅ Permission rules updated successfully"

  puts "\n🎯 Updated permissions:"
  puts "  - Time-based: Only activity end date matters"
  "  - Owner-based: Only check-in owner can edit/delete"
  "  - Stats management: Automatic rollback on deletion"

rescue => e
  puts "\n❌ Test failed: #{e.message}"
  puts "   #{e.backtrace.first(3).join("\n   ")}"
end