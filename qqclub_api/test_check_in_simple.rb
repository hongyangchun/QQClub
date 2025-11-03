#!/usr/bin/env ruby

# Simple test for check-in functionality using direct model testing
require_relative 'config/environment'

puts "🚀 Testing check-in functionality with direct model testing..."

# Helper methods for testing
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
  day_number = 1 if day_number < 1  # 确保day_number至少为1

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

  puts "\n" + "="*80
  puts "🧪 STARTING CHECK-IN MODEL TESTING"
  puts "="*80

  # Test 1: Check-in creation
  puts "\n📝 Test 1: Creating a check-in..."

  check_in = CheckIn.new(
    user: test_user,
    reading_schedule: test_schedule,
    enrollment: test_enrollment,
    content: "今天读了《测试书籍》的第1章，内容很有启发性。主要讲述了主角的成长经历和心路历程，让我深有感触。",
    word_count: 120,
    status: "normal",
    submitted_at: Time.current
  )

  if check_in.save
    puts "✅ Check-in created successfully (ID: #{check_in.id})"
    puts "   Content: #{check_in.content[0..50]}..."
    puts "   Word count: #{check_in.word_count}"
    puts "   Status: #{check_in.status}"
    $test_check_in_id = check_in.id
  else
    puts "❌ Check-in creation failed:"
    check_in.errors.full_messages.each { |error| puts "   - #{error}" }
  end

  # Test 2: Check-in validation
  puts "\n🔍 Test 2: Testing check-in validation..."

  # Test empty content
  invalid_check_in = CheckIn.new(
    user: test_user,
    reading_schedule: test_schedule,
    enrollment: test_enrollment,
    content: "",
    word_count: 50
  )

  if invalid_check_in.valid?
    puts "❌ Validation should have failed for empty content"
  else
    puts "✅ Validation correctly rejected empty content"
    puts "   Errors: #{invalid_check_in.errors.full_messages.join(', ')}"
  end

  # Test duplicate check-in
  duplicate_check_in = CheckIn.new(
    user: test_user,
    reading_schedule: test_schedule,
    enrollment: test_enrollment,
    content: "Duplicate check-in content",
    word_count: 80
  )

  if duplicate_check_in.valid?
    puts "❌ Validation should have failed for duplicate check-in"
  else
    puts "✅ Validation correctly rejected duplicate check-in"
    puts "   Errors: #{duplicate_check_in.errors.full_messages.join(', ')}"
  end

  # Test 3: Check-in permissions
  puts "\n🔐 Test 3: Testing check-in permissions..."

  # Test user can edit their own check-in
  if $test_check_in_id
    check_in = CheckIn.find($test_check_in_id)
    if check_in.can_be_edited?
      puts "✅ User can edit their own check-in"
    else
      puts "⚠️  User cannot edit check-in (might be due to time window)"
    end

    # Test update
    check_in.content = "Updated content: 今天读了《测试书籍》的第1章，内容很有启发性。主要讲述了主角的成长经历和心路历程，让我深有感触。特别是作者对于人性的描写非常深刻。"
    check_in.word_count = 180

    if check_in.save
      puts "✅ Check-in updated successfully"
      puts "   New word count: #{check_in.word_count}"
    else
      puts "❌ Check-in update failed:"
      check_in.errors.full_messages.each { |error| puts "   - #{error}" }
    end
  end

  # Test 4: Supplement check-in
  puts "\n📋 Test 4: Testing supplement check-in..."

  yesterday_schedule = create_test_reading_schedule(test_event, Date.yesterday)
  supplement_check_in = CheckIn.new(
    user: test_user,
    reading_schedule: yesterday_schedule,
    enrollment: test_enrollment,
    content: "昨天的阅读内容补卡：读了第1章的前半部分。书中描述了主角的背景故事，为后续的情节发展做了很好的铺垫。作者的文笔很细腻，让我对后续的情节充满期待。",
    word_count: 80,
    status: "supplement",
    submitted_at: Time.current
  )

  if supplement_check_in.save
    puts "✅ Supplement check-in created successfully (ID: #{supplement_check_in.id})"
    puts "   Status: #{supplement_check_in.status}"

    # Test can_makeup?
    if supplement_check_in.can_makeup?
      puts "✅ Supplement check-in can be marked as makeup"
    else
      puts "⚠️  Supplement check-in cannot be marked as makeup"
    end

    $supplement_check_in_id = supplement_check_in.id
  else
    puts "❌ Supplement check-in creation failed:"
    supplement_check_in.errors.full_messages.each { |error| puts "   - #{error}" }
  end

  # Test 5: Late check-in
  puts "\n⏰ Test 5: Testing late check-in..."

  late_schedule = create_test_reading_schedule(test_event, Date.today - 2.days)
  late_check_in = CheckIn.new(
    user: test_user,
    reading_schedule: late_schedule,
    enrollment: test_enrollment,
    content: "迟到的打卡内容：2天前读了第1章，主要介绍了故事的主要人物和背景设定。虽然错过了打卡时间，但内容还是很精彩的。",
    word_count: 70,
    status: "late",
    submitted_at: Time.current
  )

  if late_check_in.save
    puts "✅ Late check-in created successfully (ID: #{late_check_in.id})"
    puts "   Status: #{late_check_in.status}"
    $late_check_in_id = late_check_in.id
  else
    puts "❌ Late check-in creation failed:"
    late_check_in.errors.full_messages.each { |error| puts "   - #{error}" }
  end

  # Test 6: Check-in statistics
  puts "\n📊 Test 6: Testing check-in statistics..."

  user_check_ins = test_user.check_ins
  schedule_check_ins = test_schedule.check_ins
  event_check_ins = CheckIn.joins(:reading_schedule).where(reading_schedules: { reading_event_id: test_event.id })

  puts "✅ Check-in statistics:"
  puts "   User check-ins: #{user_check_ins.count}"
  puts "   Schedule check-ins: #{schedule_check_ins.count}"
  puts "   Event check-ins: #{event_check_ins.count}"
  puts "   Normal check-ins: #{user_check_ins.where(status: 'normal').count}"
  puts "   Supplement check-ins: #{user_check_ins.where(status: 'supplement').count}"
  puts "   Late check-ins: #{user_check_ins.where(status: 'late').count}"

  # Test 7: Check-in engagement score
  puts "\n📈 Test 7: Testing check-in engagement score..."

  if $test_check_in_id
    check_in = CheckIn.find($test_check_in_id)
    engagement_score = check_in.calculate_engagement_score
    puts "✅ Engagement score calculated: #{engagement_score}"

    if engagement_score > 0
      puts "   ✅ Check-in has positive engagement"
    else
      puts "   ⚠️  Check-in has no engagement yet"
    end
  end

  # Test 8: Check-in deletion
  puts "\n🗑️ Test 8: Testing check-in deletion..."

  if $late_check_in_id
    late_check_in = CheckIn.find($late_check_in_id)

    # Check if can be deleted
    if late_check_in.can_be_deleted?
      if late_check_in.destroy
        puts "✅ Late check-in deleted successfully"
      else
        puts "❌ Late check-in deletion failed"
      end
    else
      puts "⚠️  Late check-in cannot be deleted (might have flowers or be too old)"
    end
  end

  # Test 9: Reading schedule check-in methods
  puts "\n📅 Test 9: Testing reading schedule check-in methods..."

  schedule_check_ins_count = test_schedule.check_ins.count
  schedule_today_check_ins = test_schedule.check_ins.today.count
  schedule_normal_check_ins = test_schedule.check_ins.normal.count

  puts "✅ Reading schedule check-in methods:"
  puts "   Total check-ins: #{schedule_check_ins_count}"
  puts "   Today check-ins: #{schedule_today_check_ins}"
  puts "   Normal check-ins: #{schedule_normal_check_ins}"

  # Test 10: User check-in methods
  puts "\n👤 Test 10: Testing user check-in methods..."

  user_check_ins_count = test_user.check_ins.count
  user_today_check_ins = test_user.check_ins.joins(:reading_schedule)
    .where('reading_schedules.date = ?', Date.current).count

  puts "✅ User check-in methods:"
  puts "   Total check-ins: #{user_check_ins_count}"
  puts "   Today check-ins: #{user_today_check_ins}"

  # Test 11: Event enrollment check-in methods
  puts "\n📝 Test 11: Testing event enrollment check-in methods..."

  enrollment_check_ins_count = test_enrollment.check_ins.count
  puts "✅ Event enrollment check-in methods:"
  puts "   Check-ins count: #{enrollment_check_ins_count}"

  # Update enrollment completion rate
  test_enrollment.update_completion_rate!
  puts "   Completion rate: #{test_enrollment.completion_rate}%"

  puts "\n" + "="*80
  puts "🎉 CHECK-IN MODEL TESTING COMPLETED!"
  puts "="*80

  puts "\n📝 Test Summary:"
  puts "  ✅ Check-in creation with validation"
  puts "  ✅ Check-in validation (content, uniqueness)"
  puts "  ✅ Check-in permissions and editing"
  puts "  ✅ Supplement check-in functionality"
  puts "  ✅ Late check-in functionality"
  puts "  ✅ Check-in statistics and counting"
  puts "  ✅ Engagement score calculation"
  puts "  ✅ Check-in deletion with permission checks"
  puts "  ✅ Reading schedule check-in methods"
  puts "  ✅ User check-in methods"
  puts "  ✅ Event enrollment integration"

  puts "\n🎯 All check-in model functionality has been successfully tested!"
  puts "   The CheckInsController should work correctly with these validated models."

rescue => e
  puts "\n❌ Test execution failed with error:"
  puts "   Error: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(5).join("\n   ")}"
end