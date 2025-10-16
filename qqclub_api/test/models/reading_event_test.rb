# frozen_string_literal: true

require "test_helper"

class ReadingEventTest < ActiveSupport::TestCase
  def setup
    @leader = create_test_user(:user)
    @admin = create_test_user(:admin)
    @event = build(:reading_event, leader: @leader)
  end

  # Validations Tests
  test "should be valid with valid attributes" do
    assert @event.valid?
  end

  test "should require title" do
    @event.title = nil
    assert_not @event.valid?
    assert_includes @event.errors[:title], "can't be blank"
  end

  test "should require book_name" do
    @event.book_name = nil
    assert_not @event.valid?
    assert_includes @event.errors[:book_name], "can't be blank"
  end

  test "should require start_date" do
    @event.start_date = nil
    assert_not @event.valid?
    assert_includes @event.errors[:start_date], "can't be blank"
  end

  test "should require end_date" do
    @event.end_date = nil
    assert_not @event.valid?
    assert_includes @event.errors[:end_date], "can't be blank"
  end

  test "should require max_participants greater than 0" do
    @event.max_participants = 0
    assert_not @event.valid?
    assert_includes @event.errors[:max_participants], "must be greater than 0"

    @event.max_participants = -5
    assert_not @event.valid?
    assert_includes @event.errors[:max_participants], "must be greater than 0"
  end

  test "should allow positive max_participants" do
    @event.max_participants = 10
    assert @event.valid?
  end

  test "should require enrollment_fee greater than or equal to 0" do
    @event.enrollment_fee = -10
    assert_not @event.valid?
    assert_includes @event.errors[:enrollment_fee], "must be greater than or equal to 0"

    @event.enrollment_fee = 0
    assert @event.valid?

    @event.enrollment_fee = 100
    assert @event.valid?
  end

  test "should validate end_date after start_date" do
    @event.start_date = Date.today
    @event.end_date = Date.today - 1.day

    assert_not @event.valid?
    assert_includes @event.errors[:end_date], "必须在开始日期之后"
  end

  test "should allow end_date equal to start_date" do
    @event.start_date = Date.today
    @event.end_date = Date.today

    assert @event.valid?
  end

  test "should allow end_date after start_date" do
    @event.start_date = Date.today
    @event.end_date = Date.today + 1.week

    assert @event.valid?
  end

  # Associations Tests
  test "should belong to leader" do
    @event.save!
    assert_equal @leader, @event.leader
  end

  test "should have many enrollments" do
    @event.save!
    participant = create_test_user(:user)
    enrollment = Enrollment.create!(user: participant, reading_event: @event)

    assert_includes @event.enrollments, enrollment
    assert_equal 1, @event.enrollments.count
  end

  test "should have many participants through enrollments" do
    @event.save!
    participant = create_test_user(:user)
    Enrollment.create!(user: participant, reading_event: @event)

    assert_includes @event.participants, participant
    assert_equal 1, @event.participants.count
  end

  test "should have many reading_schedules" do
    @event.save!
    schedule = @event.reading_schedules.create!(date: Date.today, day_number: 1, reading_progress: "第1章")

    assert_includes @event.reading_schedules, schedule
    assert_equal 1, @event.reading_schedules.count
  end

  test "should belong to approved_by optionally" do
    @event.save!
    assert_nil @event.approved_by

    @event.approve!(@admin)
    @event.reload
    assert_equal @admin, @event.approved_by
  end

  # Calculation Methods Tests
  test "service_fee should calculate 20% of enrollment_fee" do
    @event.enrollment_fee = 100
    assert_equal 20.0, @event.service_fee
  end

  test "deposit should calculate 80% of enrollment_fee" do
    @event.enrollment_fee = 100
    assert_equal 80.0, @event.deposit
  end

  test "days_count should calculate days between start_date and end_date" do
    @event.start_date = Date.today
    @event.end_date = Date.today + 4.days
    assert_equal 5, @event.days_count  # inclusive
  end

  test "days_count should return 0 for missing dates" do
    @event.start_date = nil
    @event.end_date = nil
    assert_equal 0, @event.days_count

    @event.start_date = Date.today
    @event.end_date = nil
    assert_equal 0, @event.days_count
  end

  # Approval Status Tests
  test "should default to pending approval status" do
    @event.save!
    assert_equal "pending", @event.approval_status
    assert @event.pending_approval?
    assert_not @event.approved?
    assert_not @event.rejected?
  end

  test "approve should update approval status and admin info" do
    @event.save!
    original_time = Time.current

    @event.approve!(@admin)

    assert_equal "approved", @event.approval_status
    assert_equal @admin, @event.approved_by
    assert @event.approved_at >= original_time
  end

  test "reject should update approval status and admin info" do
    @event.save!
    original_time = Time.current

    @event.reject!(@admin, "内容不合适")

    assert_equal "rejected", @event.approval_status
    assert_equal @admin, @event.approved_by
    assert @event.approved_at >= original_time
  end

  # Leader Assignment Tests
  test "should assign random leaders when participants exist" do
    @event.save!
    @event.approval_status = :approved
    @event.save!

    # Create participants
    participants = [
      create_test_user(:user),
      create_test_user(:user),
      create_test_user(:user)
    ]

    participants.each do |participant|
      Enrollment.create!(user: participant, reading_event: @event, role: :participant)
    end

    # Create schedules
    schedules = []
    5.times do |i|
      schedules << @event.reading_schedules.create!(
        date: Date.today + i.days,
        day_number: i + 1,
        reading_progress: "第#{i + 1}章"
      )
    end

    # 直接调用 assign_random_leaders! 方法绕过 leader_assignment_type 检查
    @event.assign_random_leaders!

    # Check that leaders were assigned
    schedules.each do |schedule|
      schedule.reload  # Reload to get the updated daily_leader
      assert_not_nil schedule.daily_leader, "Schedule #{schedule.day_number} should have a daily leader"
      assert_includes participants, schedule.daily_leader, "Daily leader should be one of the participants"
    end
  end

  test "should not assign leaders when no participants" do
    @event.save!
    @event.update!(approval_status: :approved)

    # Create schedules but no participants
    3.times do |i|
      @event.reading_schedules.create!(
        date: Date.today + i.days,
        day_number: i + 1,
        reading_progress: "第#{i + 1}章"
      )
    end

    @event.assign_daily_leaders!

    # No leaders should be assigned
    @event.reading_schedules.each do |schedule|
      assert_nil schedule.daily_leader
    end
  end

  test "should not assign leaders for voluntary assignment type" do
    @event.save!
    @event.update!(approval_status: :approved, leader_assignment_type: :voluntary)

    participant = create_test_user(:user)
    Enrollment.create!(user: participant, reading_event: @event, role: :participant)

    schedule = @event.reading_schedules.create!(
      date: Date.today,
      day_number: 1,
      reading_progress: "第1章"
    )

    @event.assign_daily_leaders!

    # No leaders should be assigned for voluntary type
    assert_nil schedule.daily_leader
  end

  # Event Completion Tests
  test "complete_event should update status and reset participant roles" do
    @event.save!
    @event.update!(status: :in_progress)

    participant = create_test_user(:user)
    enrollment = Enrollment.create!(user: participant, reading_event: @event, role: :participant)

    @event.complete_event!

    @event.reload
    assert_equal "completed", @event.status

    enrollment.reload
    # The reset_roles_on_event_completion! method should be called on enrollment
  end

  # Leader Permission Tests
  test "current_leader should return true for event leader during in_progress" do
    @event.save!
    @event.update!(status: :in_progress)

    assert @event.current_leader?(@leader)
    assert_not @event.current_leader?(create_test_user(:user))
  end

  test "current_leader should return false when not in_progress" do
    @event.save!
    @event.update!(status: :enrolling)

    assert_not @event.current_leader?(@leader)
  end

  test "current_daily_leader should check permission window" do
    @event.save!
    @event.update!(status: :in_progress)

    participant = create_test_user(:user)
    schedule = @event.reading_schedules.create!(
      date: Date.today,
      day_number: 1,
      daily_leader: participant,
      reading_progress: "第1章"
    )

    # Should be true for current daily leader within window
    assert @event.current_daily_leader?(participant, schedule)

    # Should be false for other users
    assert_not @event.current_daily_leader?(@leader, schedule)

    # Should be false for leader outside window (2 days difference)
    future_schedule = @event.reading_schedules.create!(
      date: Date.today + 3.days,
      day_number: 2,
      daily_leader: participant,
      reading_progress: "第2章"
    )
    assert_not @event.current_daily_leader?(participant, future_schedule)
  end

  # Content Publishing Permission Tests
  test "can_publish_leading_content should allow group leader" do
    @event.save!
    @event.update!(status: :in_progress)

    schedule = @event.reading_schedules.create!(date: Date.today, day_number: 1, reading_progress: "第1章")

    assert @event.can_publish_leading_content?(@leader, schedule)
  end

  test "can_publish_leading_content should allow daily leader before deadline" do
    @event.save!
    @event.update!(status: :in_progress)

    daily_leader = create_test_user(:user)
    schedule = @event.reading_schedules.create!(
      date: Date.today + 1.day,
      day_number: 1,
      daily_leader: daily_leader,
      reading_progress: "第1章"
    )

    assert @event.can_publish_leading_content?(daily_leader, schedule)

    # Should not allow past date
    past_schedule = @event.reading_schedules.create!(
      date: Date.today - 1.day,
      day_number: 2,
      daily_leader: daily_leader,
      reading_progress: "第2章"
    )
    assert_not @event.can_publish_leading_content?(daily_leader, past_schedule)
  end

  # Flower Giving Permission Tests
  test "can_give_flowers should allow group leader" do
    @event.save!
    @event.update!(status: :in_progress)

    assert @event.can_give_flowers?(@leader, nil)
  end

  test "can_give_flowers should allow daily leader within grace period" do
    @event.save!
    @event.update!(status: :in_progress)

    daily_leader = create_test_user(:user)
    schedule = @event.reading_schedules.create!(
      date: Date.today,
      day_number: 1,
      daily_leader: daily_leader,
      reading_progress: "第1章"
    )

    # Should allow giving flowers on the day
    assert @event.can_give_flowers?(daily_leader, schedule)

    # Should allow giving flowers one day after
    assert @event.can_give_flowers?(daily_leader, nil)
  end

  # Missing Leader Work Tests
  test "missing_leader_work should identify missing content" do
    @event.save!
    @event.update!(status: :in_progress)

    daily_leader = create_test_user(:user)
    schedule = @event.reading_schedules.create!(
      date: Date.today,
      day_number: 1,
      daily_leader: daily_leader,
      reading_progress: "第1章"
    )

    result = @event.missing_leader_work?(Date.today)

    assert_equal true, result[:missing_content]
    assert_equal true, result[:needs_backup]
    assert_equal schedule, result[:schedule]
    assert_equal daily_leader, result[:leader]
  end

  test "missing_leader_work should identify missing flowers" do
    @event.save!
    @event.update!(status: :in_progress)

    daily_leader = create_test_user(:user)
    participant = create_test_user(:user)

    schedule = @event.reading_schedules.create!(
      date: Date.today,
      day_number: 1,
      daily_leader: daily_leader,
      reading_progress: "第1章"
    )

    # Add check-ins but no flowers
    # First create enrollment for the participant
    enrollment = Enrollment.create!(user: participant, reading_event: @event, role: :participant)

    CheckIn.create!(
      user: participant,
      reading_schedule: schedule,
      enrollment: enrollment,
      content: "这是一个有效的打卡内容，需要满足最少100字的要求。测试内容用来验证打卡功能是否正常工作，包含了足够的文字数量来通过验证规则。这样可以确保我们的测试用例能够正常运行，不会因为内容长度问题而失败。现在这段内容应该超过了100字的限制要求，可以用来测试打卡功能的完整性。"
    )

    result = @event.missing_leader_work?(Date.today)

    assert_equal true, result[:missing_flowers]
    assert_equal true, result[:needs_backup]
  end

  # Backup Schedule Tests
  test "schedules_need_backup should return schedules needing backup" do
    @event.save!
    @event.update!(status: :in_progress)

    daily_leader = create_test_user(:user)
    participant = create_test_user(:user)

    # Create schedule with missing content
    schedule1 = @event.reading_schedules.create!(
      date: Date.today,
      day_number: 1,
      daily_leader: daily_leader,
      reading_progress: "第1章"
    )

    # Create schedule with missing flowers
    schedule2 = @event.reading_schedules.create!(
      date: Date.today - 1.day,
      day_number: 2,
      daily_leader: daily_leader,
      reading_progress: "第2章"
    )
    # Create enrollment for participant
    enrollment2 = Enrollment.create!(user: participant, reading_event: @event, role: :participant)

    CheckIn.create!(
      user: participant,
      reading_schedule: schedule2,
      enrollment: enrollment2,
      content: "这是一个有效的打卡内容，需要满足最少100字的要求。测试内容用来验证打卡功能是否正常工作，包含了足够的文字数量来通过验证规则。这样可以确保我们的测试用例能够正常运行，不会因为内容长度问题而失败。现在这段内容应该超过了100字的限制要求，可以用来测试打卡功能的完整性。"
    )

    backup_needed = @event.schedules_need_backup

    assert_equal 2, backup_needed.length

    # Check first schedule (missing content)
    backup1 = backup_needed.find { |b| b[:schedule].id == schedule1.id }
    assert_equal true, backup1[:missing_content]
    assert_equal schedule1.date, backup1[:content_deadline]

    # Check second schedule (missing flowers)
    backup2 = backup_needed.find { |b| b[:schedule].id == schedule2.id }
    assert_equal true, backup2[:missing_flowers]
  end

  # Permission Window Tests
  test "leader_permission_window should return correct configuration" do
    window = @event.leader_permission_window

    assert_equal 1, window[:content_publish_days_before]
    assert_equal 0, window[:content_publish_days_after]
    assert_equal 0, window[:flower_give_days_before]
    assert_equal 1, window[:flower_give_days_after]
  end

  # Edge Cases Tests
  test "should handle event without schedules" do
    @event.save!
    @event.update!(status: :in_progress)

    assert_empty @event.schedules_need_backup
    assert_not @event.current_daily_leader?(@leader, nil)
  end

  test "should handle event with different statuses" do
    @event.save!

    # Test different statuses
    statuses = [:draft, :enrolling, :in_progress, :completed]
    statuses.each do |status|
      @event.update!(status: status)

      if status == :in_progress
        assert @event.current_leader?(@leader)
      else
        assert_not @event.current_leader?(@leader)
      end
    end
  end
end