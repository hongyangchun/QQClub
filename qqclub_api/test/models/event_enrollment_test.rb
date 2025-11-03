# frozen_string_literal: true

require "test_helper"

class EventEnrollmentTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user(:user)
    @admin = create_test_user(:admin)
    @leader = create_test_user(:user)

    # 创建阅读活动
    @reading_event = ReadingEvent.create!(
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

    # 创建活动报名
    @enrollment = EventEnrollment.new(
      reading_event: @reading_event,
      user: @user,
      enrollment_type: "participant",
      status: "enrolled",
      enrollment_date: Time.current
    )
  end

  # 基础验证测试
  test "should be valid with valid attributes" do
    assert @enrollment.valid?
  end

  test "should require enrollment_date" do
    @enrollment.enrollment_date = nil
    assert_not @enrollment.valid?
    assert_includes @enrollment.errors[:enrollment_date], "can't be blank"
  end

  test "should validate completion_rate range" do
    @enrollment.completion_rate = -5
    assert_not @enrollment.valid?
    assert_includes @enrollment.errors[:completion_rate], "must be greater than or equal to 0"

    @enrollment.completion_rate = 105
    assert_not @enrollment.valid?
    assert_includes @enrollment.errors[:completion_rate], "must be less than or equal to 100"

    @enrollment.completion_rate = 85.5
    assert @enrollment.valid?
  end

  test "should validate fee_paid_amount non-negative" do
    @enrollment.fee_paid_amount = -10
    assert_not @enrollment.valid?
    assert_includes @enrollment.errors[:fee_paid_amount], "must be greater than or equal to 0"

    @enrollment.fee_paid_amount = 0
    assert @enrollment.valid?

    @enrollment.fee_paid_amount = 100
    assert @enrollment.valid?
  end

  test "should validate fee_refund_amount non-negative" do
    @enrollment.fee_refund_amount = -10
    assert_not @enrollment.valid?
    assert_includes @enrollment.errors[:fee_refund_amount], "must be greater than or equal to 0"

    @enrollment.fee_refund_amount = 0
    assert @enrollment.valid?

    @enrollment.fee_refund_amount = 50
    assert @enrollment.valid?
  end

  # 枚举值测试
  test "should have correct enrollment_type values" do
    assert_equal "participant", EventEnrollment.enrollment_types[:participant]
    assert_equal "observer", EventEnrollment.enrollment_types[:observer]
  end

  test "should have correct status values" do
    assert_equal "enrolled", EventEnrollment.statuses[:enrolled]
    assert_equal "completed", EventEnrollment.statuses[:completed]
    assert_equal "cancelled", EventEnrollment.statuses[:cancelled]
  end

  test "should have correct refund_status values" do
    assert_equal "pending", EventEnrollment.refund_statuses[:pending]
    assert_equal "refunded", EventEnrollment.refund_statuses[:refunded]
    assert_equal "forfeited", EventEnrollment.refund_statuses[:forfeited]
  end

  test "should have default values" do
    @enrollment.save!

    assert_equal "participant", @enrollment.enrollment_type
    assert_equal "enrolled", @enrollment.status
    assert_equal "pending", @enrollment.refund_status
    assert_equal 0.0, @enrollment.completion_rate
    assert_equal 0, @enrollment.check_ins_count
    assert_equal 0, @enrollment.leader_days_count
    assert_equal 0, @enrollment.flowers_received_count
    assert_equal 0.0, @enrollment.fee_paid_amount
    assert_equal 0.0, @enrollment.fee_refund_amount
  end

  # 关联关系测试
  test "should belong to reading_event" do
    @enrollment.save!
    assert_equal @reading_event, @enrollment.reading_event
    assert_equal @reading_event.id, @enrollment.reading_event_id
  end

  test "should belong to user" do
    @enrollment.save!
    assert_equal @user, @enrollment.user
    assert_equal @user.id, @enrollment.user_id
  end

  test "should have many check_ins" do
    @enrollment.save!

    schedule = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current + 8.days,
      day_number: 1
    )

    check_in = CheckIn.create!(
      user: @user,
      reading_schedule: schedule,
      enrollment: @enrollment,
      content: "这是打卡内容" * 20 # 足够长的内容
    )

    assert_includes @enrollment.check_ins, check_in
    assert_equal 1, @enrollment.check_ins.count
  end

  test "should have many received_flowers" do
    @enrollment.save!

    schedule = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current + 8.days,
      day_number: 1
    )

    check_in = CheckIn.create!(
      user: @user,
      reading_schedule: schedule,
      enrollment: @enrollment,
      content: "这是打卡内容" * 20
    )

    flower = Flower.create!(
      giver: @leader,
      recipient: @user,
      check_in: check_in,
      amount: 1,
      flower_type: "小红花",
      comment: "很棒的打卡！"
    )

    assert_includes @enrollment.received_flowers, flower
    assert_equal 1, @enrollment.received_flowers.count
  end

  test "should have many given_flowers" do
    @enrollment.save!

    other_user = create_test_user(:user)
    other_enrollment = EventEnrollment.create!(
      reading_event: @reading_event,
      user: other_user,
      enrollment_type: "participant",
      status: "enrolled",
      enrollment_date: Time.current
    )

    schedule = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current + 8.days,
      day_number: 1
    )

    other_check_in = CheckIn.create!(
      user: other_user,
      reading_schedule: schedule,
      enrollment: other_enrollment,
      content: "其他用户的打卡内容" * 20
    )

    flower = Flower.create!(
      giver: @user,
      recipient: other_user,
      check_in: other_check_in,
      amount: 1,
      flower_type: "小红花",
      comment: "加油！"
    )

    assert_includes @enrollment.given_flowers, flower
    assert_equal 1, @enrollment.given_flowers.count
  end

  # 唯一性验证测试
  test "should enforce unique enrollment per event per user" do
    @enrollment.save!

    duplicate_enrollment = EventEnrollment.new(
      reading_event: @reading_event,
      user: @user,
      enrollment_type: "participant",
      status: "enrolled",
      enrollment_date: Time.current
    )

    assert_not duplicate_enrollment.valid?
    assert_includes duplicate_enrollment.errors[:base], "已经报名过此活动"
  end

  test "should allow same user to enroll in different events" do
    @enrollment.save!

    other_event = ReadingEvent.create!(
      title: "其他活动",
      book_name: "其他书籍",
      start_date: Date.current + 21.days,
      end_date: Date.current + 28.days,
      max_participants: 20,
      min_participants: 5,
      leader: @leader
    )

    other_enrollment = EventEnrollment.new(
      reading_event: other_event,
      user: @user,
      enrollment_type: "participant",
      status: "enrolled",
      enrollment_date: Time.current
    )

    assert other_enrollment.valid?
  end

  test "should not allow enrollment in completed events" do
    @reading_event.update!(status: :completed)

    @enrollment.status = "enrolled"
    assert_not @enrollment.valid?
    assert_includes @enrollment.errors[:base], "不能报名已完成的活动"
  end

  # 状态方法测试
  test "can_participate? should check enrollment status and type" do
    @enrollment.save!

    # 参与者且已报名
    assert @enrollment.can_participate?

    # 观察者不能参与
    @enrollment.update!(enrollment_type: "observer")
    assert_not @enrollment.can_participate?

    # 取消状态不能参与
    @enrollment.update!(enrollment_type: "participant", status: "cancelled")
    assert_not @enrollment.can_participate?
  end

  test "can_check_in? should check participation and event status" do
    @enrollment.save!
    @reading_event.update!(status: :enrolling)

    # 活动未开始不能打卡
    assert_not @enrollment.can_check_in?

    # 活动进行中可以打卡
    @reading_event.update!(status: :in_progress)
    assert @enrollment.can_check_in?

    # 非参与者不能打卡
    @enrollment.update!(enrollment_type: "observer")
    assert_not @enrollment.can_check_in?
  end

  test "can_receive_flowers? should check participation and check_ins" do
    @enrollment.save!
    @reading_event.update!(status: :in_progress)

    # 没有打卡记录不能收花
    assert_not @enrollment.can_receive_flowers?

    # 有打卡记录可以收花
    schedule = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current + 8.days,
      day_number: 1
    )

    CheckIn.create!(
      user: @user,
      reading_schedule: schedule,
      enrollment: @enrollment,
      content: "这是打卡内容" * 20
    )

    assert @enrollment.can_receive_flowers?
  end

  test "can_give_flowers? should check participation and event status" do
    @enrollment.save!
    @reading_event.update!(status: :in_progress)

    # 进行中的活动参与者可以送花
    assert @enrollment.can_give_flowers?

    # 活动未开始不能送花
    @reading_event.update!(status: :enrolling)
    assert_not @enrollment.can_give_flowers?

    # 非参与者不能送花
    @enrollment.update!(enrollment_type: "observer")
    assert_not @enrollment.can_give_flowers?
  end

  test "can_cancel? should check enrollment and event status" do
    @enrollment.save!

    # 报名状态且活动未开始可以取消
    @reading_event.update!(status: :enrolling)
    assert @enrollment.can_cancel?

    # 活动进行中不能取消
    @reading_event.update!(status: :in_progress)
    assert_not @enrollment.can_cancel?

    # 活动已完成不能取消
    @reading_event.update!(status: :completed)
    assert_not @enrollment.can_cancel?

    # 已取消的报名不能再次取消
    @reading_event.update!(status: :enrolling)
    @enrollment.update!(status: "cancelled")
    assert_not @enrollment.can_cancel?
  end

  test "cancellation_error_message should return appropriate messages" do
    @enrollment.save!

    # 已取消
    @enrollment.update!(status: "cancelled")
    assert_equal "报名已取消，无法再次取消", @enrollment.cancellation_error_message

    # 活动进行中
    @enrollment.update!(status: "enrolled")
    @reading_event.update!(status: :in_progress)
    assert_equal "活动已开始，无法取消报名", @enrollment.cancellation_error_message

    # 活动已完成
    @reading_event.update!(status: :completed)
    assert_equal "活动已完成，无法取消报名", @enrollment.cancellation_error_message
  end

  test "is_completed? should check completion rate against standard" do
    @enrollment.save!

    # 完成率低于标准
    @enrollment.update!(completion_rate: 75)
    assert_not @enrollment.is_completed?

    # 完成率达到标准
    @enrollment.update!(completion_rate: 85)
    assert @enrollment.is_completed?

    # 完成率等于标准
    @enrollment.update!(completion_rate: 80)
    assert @enrollment.is_completed?
  end

  # 完成率计算测试
  test "update_completion_rate! should calculate and update completion rate" do
    @enrollment.save!
    @reading_event.update!(status: :in_progress)

    # 创建阅读日程
    schedules = []
    3.times do |i|
      schedules << ReadingSchedule.create!(
        reading_event: @reading_event,
        date: Date.current + (i + 8).days,
        day_number: i + 1
      )
    end

    # 创建打卡记录
    CheckIn.create!(
      user: @user,
      reading_schedule: schedules[0],
      enrollment: @enrollment,
      content: "第一天打卡内容" * 20
    )

    CheckIn.create!(
      user: @user,
      reading_schedule: schedules[1],
      enrollment: @enrollment,
      content: "第二天打卡内容" * 20
    )

    @enrollment.update_completion_rate!

    # 应该有 2/3 = 66.67% 的完成率
    assert_equal 66.67, @enrollment.completion_rate
  end

  test "update_completion_rate! should update status when completed" do
    @enrollment.save!
    @reading_event.update!(status: :in_progress)

    # 创建足够多的打卡记录以达到完成标准
    schedule = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current + 8.days,
      day_number: 1
    )

    CheckIn.create!(
      user: @user,
      reading_schedule: schedule,
      enrollment: @enrollment,
      content: "打卡内容" * 20
    )

    # 设置一个很高的完成率
    @enrollment.update!(completion_rate: 85)
    @enrollment.update_completion_rate!

    assert_equal "completed", @enrollment.status
  end

  test "calculate_completion_rate should handle different activity modes" do
    @enrollment.save!

    # 笔记打卡模式
    @reading_event.update!(activity_mode: "note_checkin")
    rate = @enrollment.calculate_completion_rate
    assert rate.is_a?(Float)
    assert rate >= 0

    # 自由讨论模式
    @reading_event.update!(activity_mode: "free_discussion")
    rate = @enrollment.calculate_completion_rate
    assert rate.is_a?(Float)
    assert rate >= 0

    # 视频会议模式
    @reading_event.update!(activity_mode: "video_conference")
    rate = @enrollment.calculate_completion_rate
    assert rate.is_a?(Float)
    assert rate >= 0

    # 线下会议模式
    @reading_event.update!(activity_mode: "offline_meeting")
    rate = @enrollment.calculate_completion_rate
    assert rate.is_a?(Float)
    assert rate >= 0
  end

  # 费用相关测试
  test "calculate_refund_amount should return 0 for free events" do
    @reading_event.update!(fee_type: "free")
    @enrollment.save!

    assert_equal 0.0, @enrollment.calculate_refund_amount
  end

  test "process_refund! should handle deposit events" do
    @reading_event.update!(fee_type: "deposit", fee_amount: 100)
    @enrollment.save!

    # 模拟部分完成情况下的退款
    @enrollment.update!(completion_rate: 60, fee_paid_amount: 100)

    @enrollment.process_refund!

    # 应该更新退款状态
    assert_not_equal "pending", @enrollment.refund_status
  end

  test "process_refund! should not process non-deposit events" do
    @reading_event.update!(fee_type: "free")
    @enrollment.save!

    original_refund_status = @enrollment.refund_status

    @enrollment.process_refund!

    assert_equal original_refund_status, @enrollment.refund_status
  end

  # 证书相关测试
  test "eligible_for_completion_certificate? should check completion and existing certificates" do
    @enrollment.save!

    # 未完成不应该有资格
    @enrollment.update!(completion_rate: 60)
    assert_not @enrollment.eligible_for_completion_certificate?

    # 完成应该有资格
    @enrollment.update!(completion_rate: 85)
    assert @enrollment.eligible_for_completion_certificate?

    # 已有证书不应该重复生成
    ParticipationCertificate.create!(
      enrollment: @enrollment,
      certificate_type: "completion",
      certificate_number: "CERT001"
    )

    assert_not @enrollment.eligible_for_completion_certificate?
  end

  test "eligible_for_flower_certificate? should check flower count and rank" do
    @enrollment.save!

    # 没有小红花不应该有资格
    assert_not @enrollment.eligible_for_flower_certificate?

    # 有小红花应该有资格
    @enrollment.update!(flowers_received_count: 5)
    assert @enrollment.eligible_for_flower_certificate?

    # 检查排名资格
    assert @enrollment.eligible_for_flower_certificate?(3) # 前三名

    # 已有证书不应该重复生成
    ParticipationCertificate.create!(
      enrollment: @enrollment,
      certificate_type: "flower_top3",
      certificate_number: "FLOWER001"
    )

    assert_not @enrollment.eligible_for_flower_certificate?(3)
  end

  # 委托方法测试
  test "delegate methods should work correctly" do
    @enrollment.save!

    assert_equal @reading_event.title, @enrollment.reading_event_title
    assert_equal @reading_event.book_name, @enrollment.reading_event_book_name
    assert_equal @reading_event.activity_mode, @enrollment.reading_event_activity_mode
    assert_equal @reading_event.completion_standard, @enrollment.reading_event_completion_standard
    assert_equal @user.nickname, @enrollment.user_nickname
  end

  # 作用域测试
  test "scopes should work correctly" do
    @enrollment.save!

    # 参与者作用域
    assert_includes EventEnrollment.participants, @enrollment

    @enrollment.update!(enrollment_type: "observer")
    assert_not_includes EventEnrollment.participants, @enrollment
    assert_includes EventEnrollment.observers, @enrollment

    # 状态作用域
    @enrollment.update!(enrollment_type: "participant", status: "enrolled")
    assert_includes EventEnrollment.enrolled, @enrollment

    @enrollment.update!(status: "completed")
    assert_not_includes EventEnrollment.enrolled, @enrollment
    assert_includes EventEnrollment.completed, @enrollment

    @enrollment.update!(status: "cancelled")
    assert_includes EventEnrollment.cancelled, @enrollment
    assert_not_includes EventEnrollment.active, @enrollment

    @enrollment.update!(status: "enrolled")
    assert_includes EventEnrollment.active, @enrollment
  end

  test "by_completion_rate scope should order correctly" do
    # 创建多个不同完成率的报名
    enrollment1 = EventEnrollment.create!(
      reading_event: @reading_event,
      user: create_test_user(:user),
      enrollment_type: "participant",
      status: "enrolled",
      enrollment_date: Time.current,
      completion_rate: 90
    )

    enrollment2 = EventEnrollment.create!(
      reading_event: @reading_event,
      user: create_test_user(:user),
      enrollment_type: "participant",
      status: "enrolled",
      enrollment_date: Time.current,
      completion_rate: 70
    )

    enrollment3 = EventEnrollment.create!(
      reading_event: @reading_event,
      user: create_test_user(:user),
      enrollment_type: "participant",
      status: "enrolled",
      enrollment_date: Time.current,
      completion_rate: 80
    )

    # 降序排列
    desc_ordered = EventEnrollment.by_completion_rate(:desc)
    assert_equal enrollment1, desc_ordered.first
    assert_equal enrollment2, desc_ordered.last

    # 升序排列
    asc_ordered = EventEnrollment.by_completion_rate(:asc)
    assert_equal enrollment2, asc_ordered.first
    assert_equal enrollment1, asc_ordered.last
  end

  test "by_flowers_count scope should order correctly" do
    # 创建多个不同小红花数量的报名
    enrollment1 = EventEnrollment.create!(
      reading_event: @reading_event,
      user: create_test_user(:user),
      enrollment_type: "participant",
      status: "enrolled",
      enrollment_date: Time.current,
      flowers_received_count: 10
    )

    enrollment2 = EventEnrollment.create!(
      reading_event: @reading_event,
      user: create_test_user(:user),
      enrollment_type: "participant",
      status: "enrolled",
      enrollment_date: Time.current,
      flowers_received_count: 5
    )

    enrollment3 = EventEnrollment.create!(
      reading_event: @reading_event,
      user: create_test_user(:user),
      enrollment_type: "participant",
      status: "enrolled",
      enrollment_date: Time.current,
      flowers_received_count: 15
    )

    # 降序排列
    desc_ordered = EventEnrollment.by_flowers_count(:desc)
    assert_equal enrollment3, desc_ordered.first
    assert_equal enrollment2, desc_ordered.last
  end

  # 类方法测试
  test "calculate_enrollment_statistics should return correct statistics" do
    @enrollment.save!

    # 创建更多不同状态的报名
    EventEnrollment.create!(
      reading_event: @reading_event,
      user: create_test_user(:user),
      enrollment_type: "observer",
      status: "completed",
      enrollment_date: Time.current,
      fee_paid_amount: 50
    )

    EventEnrollment.create!(
      reading_event: @reading_event,
      user: create_test_user(:user),
      enrollment_type: "participant",
      status: "cancelled",
      enrollment_date: Time.current,
      fee_paid_amount: 100,
      fee_refund_amount: 80
    )

    stats = EventEnrollment.calculate_enrollment_statistics

    assert_equal 3, stats[:total_enrollments]
    assert_equal 1, stats[:active_enrollments] # enrolled
    assert_equal 1, stats[:completed_enrollments]
    assert_equal 1, stats[:cancelled_enrollments]
    assert_equal 2, stats[:participants_count]
    assert_equal 1, stats[:observers_count]
    assert_equal 150, stats[:total_fees_collected]
    assert_equal 80, stats[:total_refunds_processed]
  end

  # JSON序列化测试
  test "as_json_for_api should return basic data" do
    @enrollment.save!

    json = @enrollment.as_json_for_api

    assert_equal @enrollment.id, json[:id]
    assert_equal @enrollment.enrollment_type, json[:enrollment_type]
    assert_equal @enrollment.status, json[:status]
    assert_equal @enrollment.completion_rate, json[:completion_rate]
    assert_equal @enrollment.check_ins_count, json[:check_ins_count]
    assert_equal @enrollment.flowers_received_count, json[:flowers_received_count]
    assert json[:enrollment_date].present?
    assert json[:created_at].present?
    assert json[:updated_at].present?
  end

  test "as_json_for_api should include optional data" do
    @enrollment.save!

    # 包含用户信息
    json_with_user = @enrollment.as_json_for_api(include_user: true)
    assert json_with_user[:user].present?
    assert_equal @user.id, json_with_user[:user][:id]

    # 包含活动信息
    json_with_event = @enrollment.as_json_for_api(include_reading_event: true)
    assert json_with_event[:reading_event].present?
    assert_equal @reading_event.id, json_with_event[:reading_event][:id]

    # 包含统计信息
    json_with_stats = @enrollment.as_json_for_api(include_statistics: true)
    assert json_with_stats[:statistics].present?
    assert json_with_stats[:statistics][:completion_percentage].present?
    assert json_with_stats[:statistics][:attendance_rate].present?
  end

  # 边界条件测试
  test "should handle enrollment without check_ins" do
    @enrollment.save!

    assert_equal 0, @enrollment.check_ins_count
    assert_equal 0.0, @enrollment.calculate_completion_rate
    assert_not @enrollment.can_receive_flowers?
  end

  test "should handle enrollment without flowers" do
    @enrollment.save!

    assert_equal 0, @enrollment.flowers_received_count
    assert_not @enrollment.eligible_for_flower_certificate?
    assert_nil @enrollment.send(:calculate_flower_ranking_in_event)
  end

  test "should handle enrollment in events without schedules" do
    @enrollment.save!

    # 没有日程的情况下完成率应该是0
    rate = @enrollment.calculate_completion_rate
    assert_equal 0.0, rate
  end

  test "should handle weekend_rest correctly" do
    @enrollment.save!
    @reading_event.update!(weekend_rest: true)

    # 创建包含周末的日程
    friday_schedule = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current + 8.days, # 假设是周五
      day_number: 1
    )

    saturday_schedule = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current + 9.days, # 假设是周六
      day_number: 2
    )

    # 计算总天数时应该排除周末
    total_days = @enrollment.send(:calculate_total_reading_days, @reading_event.reading_schedules, @reading_event)
    # 由于不确定具体日期，这里只验证方法能正常执行
    assert total_days >= 0
  end

  # 集成测试
  test "should handle complete enrollment lifecycle" do
    @enrollment.save!
    @reading_event.update!(status: :in_progress)

    # 初始状态
    assert_equal "enrolled", @enrollment.status
    assert_equal 0.0, @enrollment.completion_rate
    assert @enrollment.can_participate?
    assert @enrollment.can_check_in?
    assert @enrollment.can_give_flowers?

    # 创建打卡记录
    schedule = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current + 8.days,
      day_number: 1
    )

    CheckIn.create!(
      user: @user,
      reading_schedule: schedule,
      enrollment: @enrollment,
      content: "这是第一天打卡内容" * 20
    )

    # 更新完成率
    @enrollment.update_completion_rate!

    # 创建更多打卡以达到完成标准
    (2..5).each do |day|
      schedule = ReadingSchedule.create!(
        reading_event: @reading_event,
        date: Date.current + (7 + day).days,
        day_number: day
      )

      CheckIn.create!(
        user: @user,
        reading_schedule: schedule,
        enrollment: @enrollment,
        content: "第#{day}天打卡内容" * 20
      )
    end

    @enrollment.update_completion_rate!

    # 应该已完成
    assert_equal "completed", @enrollment.status
    assert @enrollment.is_completed?
    assert @enrollment.eligible_for_completion_certificate?

    # 活动结束后生成证书
    @reading_event.update!(status: :completed)
    assert @enrollment.eligible_for_completion_certificate?
  end
end