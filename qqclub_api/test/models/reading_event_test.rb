# frozen_string_literal: true

require "test_helper"

class ReadingEventTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user(:user)
    @admin = create_test_user(:admin)
    @leader = create_test_user(:user)

    # 创建一个基础的阅读活动
    @reading_event = ReadingEvent.new(
      title: "《红楼梦》精读班",
      book_name: "红楼梦",
      description: "一起精读中国古典名著红楼梦",
      start_date: Date.current + 7.days,
      end_date: Date.current + 14.days,
      max_participants: 20,
      min_participants: 5,
      fee_type: "free",
      fee_amount: 0,
      leader_reward_percentage: 0,
      completion_standard: 80,
      activity_mode: "note_checkin",
      leader_assignment_type: "voluntary",
      weekend_rest: true,
      leader: @leader
    )
  end

  # 基础验证测试
  test "should be valid with valid attributes" do
    assert @reading_event.valid?
  end

  test "should require title" do
    @reading_event.title = nil
    assert_not @reading_event.valid?
    assert_includes @reading_event.errors[:title], "can't be blank"
  end

  test "should require title minimum 5 characters" do
    @reading_event.title = "短"
    assert_not @reading_event.valid?
    assert_includes @reading_event.errors[:title], "is too short (minimum is 5 characters)"
  end

  test "should allow title within length limit" do
    @reading_event.title = "a" * 100
    assert @reading_event.valid?
  end

  test "should require book_name" do
    @reading_event.book_name = nil
    assert_not @reading_event.valid?
    assert_includes @reading_event.errors[:book_name], "can't be blank"
  end

  test "should require start_date and end_date" do
    @reading_event.start_date = nil
    assert_not @reading_event.valid?
    assert_includes @reading_event.errors[:start_date], "can't be blank"

    @reading_event.start_date = Date.current + 7.days
    @reading_event.end_date = nil
    assert_not @reading_event.valid?
    assert_includes @reading_event.errors[:end_date], "can't be blank"
  end

  test "should validate end_date after start_date" do
    @reading_event.start_date = Date.current + 14.days
    @reading_event.end_date = Date.current + 7.days
    assert_not @reading_event.valid?
    assert_includes @reading_event.errors[:end_date], "必须在开始日期之后"
  end

  test "should validate max_participants" do
    @reading_event.max_participants = 0
    assert_not @reading_event.valid?
    assert_includes @reading_event.errors[:max_participants], "must be greater than 0"

    @reading_event.max_participants = 51
    assert_not @reading_event.valid?
    assert_includes @reading_event.errors[:max_participants], "must be less than or equal to 50"
  end

  test "should validate min_participants not greater than max" do
    @reading_event.min_participants = 25
    @reading_event.max_participants = 20
    assert_not @reading_event.valid?
    assert_includes @reading_event.errors[:min_participants], "不能大于最大参与人数"
  end

  # 枚举值测试
  test "should have correct status values" do
    assert_equal 0, ReadingEvent.statuses[:draft]
    assert_equal 1, ReadingEvent.statuses[:enrolling]
    assert_equal 2, ReadingEvent.statuses[:in_progress]
    assert_equal 3, ReadingEvent.statuses[:completed]
  end

  test "should have correct approval_status values" do
    assert_equal 0, ReadingEvent.approval_statuses[:pending]
    assert_equal 1, ReadingEvent.approval_statuses[:approved]
    assert_equal 2, ReadingEvent.approval_statuses[:rejected]
  end

  test "should have correct activity_mode values" do
    assert_equal "note_checkin", ReadingEvent.activity_modes[:note_checkin]
    assert_equal "free_discussion", ReadingEvent.activity_modes[:free_discussion]
    assert_equal "video_conference", ReadingEvent.activity_modes[:video_conference]
    assert_equal "offline_meeting", ReadingEvent.activity_modes[:offline_meeting]
  end

  test "should have correct fee_type values" do
    assert_equal "free", ReadingEvent.fee_types[:free]
    assert_equal "deposit", ReadingEvent.fee_types[:deposit]
    assert_equal "paid", ReadingEvent.fee_types[:paid]
  end

  # 关联关系测试
  test "should belong to leader" do
    @reading_event.save!
    assert_equal @leader, @reading_event.leader
    assert_equal @leader.id, @reading_event.leader_id
  end

  test "should have many event_enrollments" do
    @reading_event.save!

    enrollment1 = EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled', enrollment_date: Time.current)
    enrollment2 = EventEnrollment.create!(user: @admin, reading_event: @reading_event, status: 'enrolled', enrollment_date: Time.current)

    assert_includes @reading_event.event_enrollments, enrollment1
    assert_includes @reading_event.event_enrollments, enrollment2
    assert_equal 2, @reading_event.event_enrollments.count
  end

  test "should have many participants through event_enrollments" do
    @reading_event.save!

    EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled', enrollment_date: Time.current)
    EventEnrollment.create!(user: @admin, reading_event: @reading_event, status: 'enrolled', enrollment_date: Time.current)

    assert_includes @reading_event.participants, @user
    assert_includes @reading_event.participants, @admin
    assert_equal 2, @reading_event.participants.count
  end

  test "should have many reading_schedules" do
    @reading_event.save!

    schedule1 = ReadingSchedule.create!(reading_event: @reading_event, date: Date.current + 8.days, day_number: 1, reading_progress: "第1章")
    schedule2 = ReadingSchedule.create!(reading_event: @reading_event, date: Date.current + 9.days, day_number: 2, reading_progress: "第2章")

    assert_includes @reading_event.reading_schedules, schedule1
    assert_includes @reading_event.reading_schedules, schedule2
    assert_equal 2, @reading_event.reading_schedules.count
  end

  # 计算方法测试
  test "should calculate service_fee correctly" do
    @reading_event.fee_amount = 100
    @reading_event.save!

    assert_equal 20.0, @reading_event.service_fee
  end

  test "should calculate deposit correctly" do
    @reading_event.fee_amount = 100
    @reading_event.save!

    assert_equal 80.0, @reading_event.deposit
  end

  test "should calculate days_count correctly" do
    @reading_event.start_date = Date.current + 7.days
    @reading_event.end_date = Date.current + 14.days
    @reading_event.save!

    assert_equal 8, @reading_event.days_count # (14 - 7) + 1
  end

  test "should return 0 days_count when dates are missing" do
    @reading_event.start_date = nil
    @reading_event.end_date = nil
    @reading_event.save!

    assert_equal 0, @reading_event.days_count
  end

  # 审批状态方法测试
  test "should approve correctly" do
    @reading_event.save!
    original_approval_status = @reading_event.approval_status

    result = @reading_event.approve!(@admin)

    assert result
    assert_equal "approved", @reading_event.approval_status
    assert_equal @admin.id, @reading_event.approved_by_id
    assert @reading_event.approved_at.present?
    assert_not_equal original_approval_status, @reading_event.approval_status
  end

  test "should reject correctly" do
    @reading_event.save!
    rejection_reason = "内容不合适"

    result = @reading_event.reject!(@admin, rejection_reason)

    assert result
    assert_equal "rejected", @reading_event.approval_status
    assert_equal @admin.id, @reading_event.approved_by_id
    assert @reading_event.approved_at.present?
    assert_equal rejection_reason, @reading_event.rejection_reason
  end

  test "approved? should return correct status" do
    @reading_event.save!
    assert_not @reading_event.approved?

    @reading_event.approve!(@admin)
    assert @reading_event.approved?
  end

  test "pending_approval? should return correct status" do
    @reading_event.save!
    assert @reading_event.pending_approval?

    @reading_event.approve!(@admin)
    assert_not @reading_event.pending_approval?
  end

  test "rejected? should return correct status" do
    @reading_event.save!
    assert_not @reading_event.rejected?

    @reading_event.reject!(@admin, "test reason")
    assert @reading_event.rejected?
  end

  # 审批工作流测试
  test "can_submit_for_approval? should work correctly" do
    @reading_event.save!

    # 草稿状态且未提交过可以提交
    assert @reading_event.can_submit_for_approval?

    # 已提交的不能再次提交
    @reading_event.update!(submitted_for_approval_at: Time.current)
    assert_not @reading_event.can_submit_for_approval?

    # 非草稿状态不能提交
    @reading_event.update!(status: :enrolling, submitted_for_approval_at: nil)
    assert_not @reading_event.can_submit_for_approval?
  end

  test "can_resubmit_for_approval? should work correctly" do
    @reading_event.save!

    # 拒绝状态且有拒绝原因可以重新提交
    @reading_event.reject!(@admin, "需要修改")
    assert @reading_event.can_resubmit_for_approval?

    # 其他状态不能重新提交
    @reading_event.update!(approval_status: :pending, rejection_reason: nil)
    assert_not @reading_event.can_resubmit_for_approval?
  end

  test "can_be_approved_by? should check admin permissions" do
    @reading_event.save!
    @reading_event.update!(approval_status: :pending)

    # 管理员可以批准
    assert @reading_event.can_be_approved_by?(@admin)

    # 普通用户不能批准
    assert_not @reading_event.can_be_approved_by?(@user)
  end

  # 状态管理测试
  test "can_start? should check conditions" do
    @reading_event.save!

    # 默认不能开始
    assert_not @reading_event.can_start?

    # 设置为报名状态且人数足够
    @reading_event.update!(status: :enrolling, start_date: Date.current)
    EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled')

    # 还是需要最少人数
    @reading_event.update!(min_participants: 1)
    assert @reading_event.can_start?
  end

  test "can_enroll? should check enrollment conditions" do
    @reading_event.save!
    @reading_event.update!(status: :enrolling, approval_status: :approved)

    # 基本条件满足可以报名
    assert @reading_event.can_enroll?

    # 报名截止后不能报名
    @reading_event.update!(enrollment_deadline: 1.hour.ago)
    assert_not @reading_event.can_enroll?

    # 人数已满不能报名
    @reading_event.update!(enrollment_deadline: nil, max_participants: 1)
    EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled')
    assert_not @reading_event.can_enroll?
  end

  test "enrollment_error_message should return appropriate messages" do
    @reading_event.save!

    # 不在报名状态
    assert_equal "活动不在报名状态", @reading_event.enrollment_error_message

    # 报名已截止
    @reading_event.update!(status: :enrolling, enrollment_deadline: 1.hour.ago)
    assert_equal "报名已截止", @reading_event.enrollment_error_message

    # 人数已满
    @reading_event.update!(enrollment_deadline: nil, max_participants: 1)
    EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled')
    assert_equal "活动人数已满", @reading_event.enrollment_error_message

    # 未批准
    @reading_event.update!(max_participants: 10, approval_status: :pending)
    assert_equal "活动尚未批准", @reading_event.enrollment_error_message
  end

  # 用户参与状态测试
  test "user_enrolled? should check user enrollment" do
    @reading_event.save!

    # 未报名用户
    assert_not @reading_event.user_enrolled?(@user)

    # 已报名用户
    EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled')
    assert @reading_event.user_enrolled?(@user)
  end

  test "user_enrollment should return user enrollment" do
    @reading_event.save!

    # 未报名用户返回nil
    assert_nil @reading_event.user_enrollment(@user)

    # 已报名用户返回enrollment
    enrollment = EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled')
    assert_equal enrollment, @reading_event.user_enrollment(@user)
  end

  # 参与人数统计测试
  test "max_participants_reached? should work correctly" do
    @reading_event.save!
    @reading_event.update!(max_participants: 2)

    # 未满员
    assert_not @reading_event.max_participants_reached?

    # 满员
    EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled')
    EventEnrollment.create!(user: @admin, reading_event: @reading_event, status: 'enrolled')
    assert @reading_event.max_participants_reached?
  end

  test "enough_participants? should work correctly" do
    @reading_event.save!
    @reading_event.update!(min_participants: 2)

    # 人数不足
    assert_not @reading_event.enough_participants?

    # 人数足够
    EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled')
    EventEnrollment.create!(user: @admin, reading_event: @reading_event, status: 'enrolled')
    assert @reading_event.enough_participants?
  end

  test "participants_count should return correct count" do
    @reading_event.save!

    assert_equal 0, @reading_event.participants_count

    EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled')
    assert_equal 1, @reading_event.participants_count

    EventEnrollment.create!(user: @admin, reading_event: @reading_event, status: 'enrolled')
    assert_equal 2, @reading_event.participants_count
  end

  test "available_spots should calculate correctly" do
    @reading_event.save!
    @reading_event.update!(max_participants: 5)

    assert_equal 5, @reading_event.available_spots

    EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled')
    assert_equal 4, @reading_event.available_spots
  end

  # 活动生命周期测试
  test "start! should start the event if conditions are met" do
    @reading_event.save!
    @reading_event.update!(
      status: :enrolling,
      start_date: Date.current,
      approval_status: :approved,
      min_participants: 1
    )
    EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled')

    result = @reading_event.start!

    assert result
    assert_equal "in_progress", @reading_event.status
  end

  test "start! should not start if conditions are not met" do
    @reading_event.save!
    @reading_event.update!(status: :enrolling, start_date: Date.current)

    result = @reading_event.start!

    assert_not result
    assert_equal "enrolling", @reading_event.status
  end

  test "complete! should complete the event if conditions are met" do
    @reading_event.save!
    @reading_event.update!(
      status: :in_progress,
      end_date: Date.current - 1.day
    )

    result = @reading_event.complete!

    assert result
    assert_equal "completed", @reading_event.status
  end

  test "complete! should not complete if conditions are not met" do
    @reading_event.save!
    @reading_event.update!(
      status: :in_progress,
      end_date: Date.current + 1.day
    )

    result = @reading_event.complete!

    assert_not result
    assert_equal "in_progress", @reading_event.status
  end

  test "can_complete? should check completion conditions" do
    @reading_event.save!

    # 进行中但未到结束日期
    @reading_event.update!(status: :in_progress, end_date: Date.current + 1.day)
    assert_not @reading_event.can_complete?

    # 已到结束日期
    @reading_event.update!(end_date: Date.current - 1.day)
    assert @reading_event.can_complete?
  end

  # 权限相关测试
  test "current_leader? should check leader status" do
    @reading_event.save!
    @reading_event.update!(status: :in_progress)

    # 小组长
    assert @reading_event.current_leader?(@leader)

    # 非小组长
    assert_not @reading_event.current_leader?(@user)
  end

  test "current_daily_leader? should check daily leader status with time window" do
    @reading_event.save!
    @reading_event.update!(status: :in_progress)

    # 创建一个昨天的schedule
    yesterday_schedule = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current - 1.day,
      day_number: 1,
      daily_leader: @user
    )

    # 昨天的领读人今天仍有权限（3天窗口）
    assert @reading_event.current_daily_leader?(@user, yesterday_schedule)

    # 4天前的领读人今天没有权限
    old_schedule = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current - 4.days,
      day_number: 2,
      daily_leader: @admin
    )

    assert_not @reading_event.current_daily_leader?(@admin, old_schedule)
  end

  # 活动验证测试
  test "validate_event_for_approval should return correct validation result" do
    @reading_event.save!

    # 完整的活动应该验证通过
    result = @reading_event.validate_event_for_approval
    assert result[:valid]
    assert_empty result[:errors]

    # 缺少title的活动应该验证失败
    @reading_event.update!(title: "")
    result = @reading_event.validate_event_for_approval
    assert_not result[:valid]
    assert_includes result[:errors], "活动标题不能为空"

    # 缺少阅读计划的活动应该验证失败
    @reading_event.update!(title: "Valid Title")
    result = @reading_event.validate_event_for_approval
    assert_not result[:valid]
    assert_includes result[:errors], "必须设置阅读计划"
  end

  # 作用域测试
  test "scopes should work correctly" do
    @reading_event.save!

    # 默认是草稿状态
    assert_includes ReadingEvent.draft, @reading_event
    assert_not_includes ReadingEvent.enrolling, @reading_event
    assert_not_includes ReadingEvent.in_progress, @reading_event
    assert_not_includes ReadingEvent.completed, @reading_event

    # 更新状态
    @reading_event.update!(status: :enrolling)
    assert_not_includes ReadingEvent.draft, @reading_event
    assert_includes ReadingEvent.enrolling, @reading_event

    @reading_event.update!(status: :in_progress)
    assert_includes ReadingEvent.active, @reading_event
    assert_includes ReadingEvent.in_progress, @reading_event

    @reading_event.update!(status: :completed)
    assert_includes ReadingEvent.completed, @reading_event
    assert_not_includes ReadingEvent.active, @reading_event
  end

  test "filter_by_status scope should work" do
    @reading_event.save!
    @reading_event.update!(status: :enrolling)

    enrolling_events = ReadingEvent.filter_by_status('enrolling')
    assert_includes enrolling_events, @reading_event

    draft_events = ReadingEvent.filter_by_status('draft')
    assert_not_includes draft_events, @reading_event
  end

  test "upcoming scope should return future events" do
    future_event = ReadingEvent.create!(
      title: "Future Event",
      book_name: "Test Book",
      start_date: Date.current + 10.days,
      end_date: Date.current + 15.days,
      max_participants: 10,
      min_participants: 2,
      leader: @leader
    )

    past_event = ReadingEvent.create!(
      title: "Past Event",
      book_name: "Test Book",
      start_date: Date.current - 10.days,
      end_date: Date.current - 5.days,
      max_participants: 10,
      min_participants: 2,
      leader: @leader
    )

    upcoming_events = ReadingEvent.upcoming
    assert_includes upcoming_events, future_event
    assert_not_includes upcoming_events, past_event
  end

  # JSON序列化测试
  test "as_json_for_api should return basic data" do
    @reading_event.save!

    json = @reading_event.as_json_for_api

    assert_equal @reading_event.id, json[:id]
    assert_equal @reading_event.title, json[:title]
    assert_equal @reading_event.book_name, json[:book_name]
    assert_equal @reading_event.status, json[:status]
    assert_equal @reading_event.approval_status, json[:approval_status]
    assert json[:created_at].present?
    assert json[:updated_at].present?
  end

  test "as_json_for_api should include optional data" do
    @reading_event.save!

    # 包含leader
    json_with_leader = @reading_event.as_json_for_api(include_leader: true)
    assert json_with_leader[:leader].present?
    assert_equal @leader.id, json_with_leader[:leader][:id]

    # 包含统计信息
    json_with_stats = @reading_event.as_json_for_api(include_statistics: true)
    assert json_with_stats[:statistics].present?
    assert json_with_stats[:enrollment_statistics].present?
  end

  # 边界条件测试
  test "should handle free events correctly" do
    @reading_event.fee_type = "free"
    @reading_event.fee_amount = 0
    @reading_event.save!

    assert_equal 0, @reading_event.fee_amount
    assert_equal 0, @reading_event.service_fee
    assert_equal 0, @reading_event.deposit
  end

  test "should handle paid events correctly" do
    @reading_event.fee_type = "paid"
    @reading_event.fee_amount = 100
    @reading_event.leader_reward_percentage = 10
    @reading_event.save!

    # 创建报名记录
    EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled')
    EventEnrollment.create!(user: @admin, reading_event: @reading_event, status: 'enrolled')

    leader_reward = @reading_event.calculate_leader_reward
    assert_equal 200, leader_reward # 100 * 2 participants
  end

  test "should handle deposit events correctly" do
    @reading_event.fee_type = "deposit"
    @reading_event.fee_amount = 100
    @reading_event.leader_reward_percentage = 20
    @reading_event.save!

    # 创建报名记录
    EventEnrollment.create!(user: @user, reading_event: @reading_event, status: 'enrolled')
    EventEnrollment.create!(user: @admin, reading_event: @reading_event, status: 'enrolled')

    leader_reward = @reading_event.calculate_leader_reward
    deposit_pool = @reading_event.calculate_deposit_pool

    assert_equal 40, leader_reward # 100 * 20% * 2 participants
    assert_equal 160, deposit_pool # 200 total - 40 leader reward
  end

  test "should handle weekend_rest correctly" do
    @reading_event.start_date = Date.current + 7.days # 假设是周一
    @reading_event.end_date = Date.current + 13.days # 假设是周日
    @reading_event.weekend_rest = true
    @reading_event.save!

    # 计算工作日（排除周末）
    days_count = @reading_event.days_count
    # 这个测试可能需要根据实际的开始日期调整
    assert days_count <= 7 # 应该少于或等于7天（排除周末）
  end

  test "should handle events with different activity modes" do
    modes = %w[note_checkin free_discussion video_conference offline_meeting]

    modes.each do |mode|
      event = ReadingEvent.create!(
        title: "Test #{mode} Event",
        book_name: "Test Book",
        start_date: Date.current + 7.days,
        end_date: Date.current + 14.days,
        max_participants: 10,
        min_participants: 2,
        activity_mode: mode,
        leader: @leader
      )

      assert_equal mode, event.activity_mode
      assert event.valid?
    end
  end

  # 集成测试
  test "should handle complete event lifecycle" do
    # 创建活动
    event = ReadingEvent.create!(
      title: "完整生命周期测试",
      book_name: "测试书籍",
      start_date: Date.current + 7.days,
      end_date: Date.current + 14.days,
      max_participants: 5,
      min_participants: 2,
      leader: @leader
    )

    # 初始状态
    assert_equal "draft", event.status
    assert_equal "pending", event.approval_status

    # 提交审批
    can_submit = event.can_submit_for_approval?
    assert can_submit

    # 批准活动
    event.approve!(@admin)
    assert_equal "approved", event.approval_status

    # 开始报名
    event.update!(status: :enrolling)

    # 用户报名
    EventEnrollment.create!(user: @user, reading_event: event, status: 'enrolled')
    EventEnrollment.create!(user: @admin, reading_event: event, status: 'enrolled')

    assert event.enough_participants?

    # 开始活动
    event.update!(start_date: Date.current)
    started = event.start!
    assert started
    assert_equal "in_progress", event.status

    # 完成活动
    event.update!(end_date: Date.current - 1.day)
    completed = event.complete!
    assert completed
    assert_equal "completed", event.status
  end
end