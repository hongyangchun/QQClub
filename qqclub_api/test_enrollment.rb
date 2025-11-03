#!/usr/bin/env ruby

# Load Rails environment
require_relative 'config/environment'

puts "Starting enrollment test..."

# Find or create test user
user = User.find(1)
puts "Found user: #{user.nickname}"

# Create a test event
event = ReadingEvent.create!(
  title: "测试报名活动",
  book_name: "测试书籍",
  start_date: Date.today + 5.days,
  end_date: Date.today + 10.days,
  description: "用于测试报名功能的活动",
  leader: user,
  status: :enrolling,
  approval_status: :approved
)
puts "Created event: #{event.id} - #{event.title}"
puts "Event status: #{event.status}"
puts "Event can enroll?: #{event.can_enroll?}"

# Test enrollment creation
enrollment = EventEnrollment.create!(
  reading_event: event,
  user: user,
  enrollment_type: :participant,
  status: :enrolled,
  enrollment_date: Time.current
)

if enrollment.persisted?
  puts "✅ Successfully created enrollment: #{enrollment.id}"
  puts "   Enrollment type: #{enrollment.enrollment_type}"
  puts "   Enrollment status: #{enrollment.status}"
  puts "   Enrollment date: #{enrollment.enrollment_date}"
else
  puts "❌ Failed to create enrollment"
  puts "   Errors: #{enrollment.errors.full_messages.join(', ')}"
end

# Test enrollment statistics
puts "\n📊 Event enrollment statistics:"
stats = event.enrollment_statistics
stats.each do |key, value|
  puts "   #{key}: #{value}"
end

# Test enrollment details
puts "\n📋 Enrollment details:"
enrollment_data = enrollment.enrollment_info if enrollment.respond_to?(:enrollment_info)
if enrollment_data
  enrollment_data.each do |key, value|
    puts "   #{key}: #{value}"
  end
end

puts "\n✅ Enrollment test completed!"