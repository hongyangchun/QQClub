# frozen_string_literal: true

require "test_helper"

class LeaderAssignmentServiceTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user(:user)
    @leader = create_test_user(:user)
    @admin = create_test_user(:admin)

    @reading_event = ReadingEvent.create!(
      title: "《水浒传》精读班",
      book_name: "水浒传",
      description: "古典名著精读活动",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 20,
      min_participants: 3,
      fee_type: "free",
      fee_amount: 0,
      leader_reward_percentage: 10,
      completion_standard: 80,
      activity_mode: "note_checkin",
      leader_assignment_type: "voluntary",
      weekend_rest: true,
      leader: @leader,
      approval_status: "approved"
    )

    # 创建阅读计划
    @schedule1 = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current + 8.days,
      day_number: 1,
      reading_progress: "第1章"
    )

    @schedule2 = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current + 9.days,
      day_number: 2,
      reading_progress: "第2章"
    )

    @schedule3 = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current + 10.days,
      day_number: 3,
      reading_progress: "第3章"
    )

    # 创建报名记录
    @enrollment = EventEnrollment.create!(
      reading_event: @reading_event,
      user: @user,
      enrollment_type: "participant",
      status: "enrolled",
      enrollment_date: Time.current
    )
  end

  # 基本功能测试
  test "should initialize service with required parameters" do
    service = LeaderAssignmentService.new(event: @reading_event, user: @user, schedule: @schedule1, action: :claim_leadership)

    assert_equal @reading_event, service.event
    assert_equal @user, service.user
    assert_equal @schedule1, service.schedule
    assert_equal :claim_leadership, service.action
    assert_equal({}, service.assignment_options)
  end

  test "should inherit from ApplicationService" do
    service = LeaderAssignmentService.new(event: @reading_event, action: :get_statistics)

    assert service.is_a?(ApplicationService)
    assert service.respond_to?(:call)
    assert service.respond_to?(:success?)
    assert service.respond_to?(:failure?)
  end

  test "should handle indifferent access for assignment options" do
    options = { "assignment_type" => "random", "max_leadership_count" => 5 }
    service = LeaderAssignmentService.new(event: @reading_event, action: :auto_assign, assignment_options: options)

    assert_equal "random", service.assignment_options[:assignment_type]
    assert_equal "random", service.assignment_options["assignment_type"]
    assert_equal 5, service.assignment_options[:max_leadership_count]
  end

  test "should handle unsupported action" do
    service = LeaderAssignmentService.new(event: @reading_event, action: :unsupported_action)

    result = service.call

    assert result.failure?
    assert_equal "不支持的操作: unsupported_action", result.message
  end

  # 自由报名领读测试
  test "should successfully claim leadership for voluntary assignment" do
    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: @user,
      schedule: @schedule1,
      action: :claim_leadership
    )

    result = service.call

    assert result.success?
    assert_equal "领读报名成功", result.message
    assert_equal @user, @schedule1.reload.daily_leader

    schedule_data = result.data[:schedule_data]
    assert_equal @schedule1.id, schedule_data[:id]
    assert_equal 1, schedule_data[:day_number]
    assert_equal @user.id, schedule_data[:leader][:id]
    assert_equal @user.nickname, schedule_data[:leader][:nickname]
  end

  test "should reject leadership claim for non-voluntary assignment type" do
    @reading_event.update!(leader_assignment_type: "random")

    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: @user,
      schedule: @schedule1,
      action: :claim_leadership
    )

    result = service.call

    assert result.failure?
    assert_equal "该活动不支持自由报名领读", result.message
  end

  test "should reject leadership claim for non-enrolled user" do
    non_enrolled_user = create_test_user(:user)

    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: non_enrolled_user,
      schedule: @schedule1,
      action: :claim_leadership
    )

    result = service.call

    assert result.failure?
    assert_equal "请先报名该活动", result.message
  end

  test "should reject leadership claim when schedule already has leader" do
    @schedule1.update!(daily_leader: @leader)

    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: @user,
      schedule: @schedule1,
      action: :claim_leadership
    )

    result = service.call

    assert result.failure?
    assert_equal "该日已有领读人", result.message
  end

  test "should reject leadership claim when user exceeds limit" do
    # 创建用户已领读3个日程的情况
    @schedule1.update!(daily_leader: @user)
    @schedule2.update!(daily_leader: @user)
    @schedule3.update!(daily_leader: @user)

    new_schedule = ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current + 11.days,
      day_number: 4,
      reading_progress: "第4章"
    )

    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: @user,
      schedule: new_schedule,
      action: :claim_leadership
    )

    result = service.call

    assert result.failure?
    assert_equal "领读次数已达上限", result.message
  end

  test "should handle class method for claiming leadership" do
    result = LeaderAssignmentService.claim_leadership!(@reading_event, @user, @schedule1)

    assert result.success?
    assert_equal "领读报名成功", result.message
    assert_equal @user, @schedule1.reload.daily_leader
  end

  # 自动分配领读人测试
  test "should auto-assign leaders with random assignment" do
    # 创建更多参与者
    participant1 = create_test_user(:user)
    participant2 = create_test_user(:user)
    participant3 = create_test_user(:user)

    [participant1, participant2, participant3].each do |participant|
      EventEnrollment.create!(
        reading_event: @reading_event,
        user: participant,
        enrollment_type: "participant",
        status: "enrolled",
        enrollment_date: Time.current
      )
    end

    service = LeaderAssignmentService.new(
      event: @reading_event,
      action: :auto_assign,
      assignment_options: { assignment_type: "random" }
    )

    result = service.call

    assert result.success?
    assert_equal "领读人分配完成", result.message
    assert_equal "random", result.data[:assignment_type]
    assert_equal 3, result.data[:assigned_count]

    # 验证每个日程都有领读人
    @reading_event.reading_schedules.reload.each do |schedule|
      assert_not_nil schedule.daily_leader
      assert_includes [@user, participant1, participant2, participant3], schedule.daily_leader
    end
  end

  test "should auto-assign leaders with balanced assignment" do
    # 创建参与者
    participant1 = create_test_user(:user)
    participant2 = create_test_user(:user)

    [participant1, participant2].each do |participant|
      EventEnrollment.create!(
        reading_event: @reading_event,
        user: participant,
        enrollment_type: "participant",
        status: "enrolled",
        enrollment_date: Time.current
      )
    end

    service = LeaderAssignmentService.new(
      event: @reading_event,
      action: :auto_assign,
      assignment_options: { assignment_type: "balanced" }
    )

    result = service.call

    assert result.success?
    assert_equal "balanced", result.data[:assignment_type]
    assert_equal 3, result.data[:assigned_count]
  end

  test "should auto-assign leaders with rotation assignment" do
    participant1 = create_test_user(:user)
    participant2 = create_test_user(:user)

    [participant1, participant2].each do |participant|
      EventEnrollment.create!(
        reading_event: @reading_event,
        user: participant,
        enrollment_type: "participant",
        status: "enrolled",
        enrollment_date: Time.current
      )
    end

    service = LeaderAssignmentService.new(
      event: @reading_event,
      action: :auto_assign,
      assignment_options: { assignment_type: "rotation" }
    )

    result = service.call

    assert result.success?
    assert_equal "rotation", result.data[:assignment_type]
    assert_equal 3, result.data[:assigned_count]

    # 验证轮换效果（连续两天不是同一个人）
    leaders = @reading_event.reading_schedules.order(:day_number).pluck(:daily_leader)
    if leaders.size >= 2
      assert_not_equal leaders[0], leaders[1], "轮换分配应该避免连续分配给同一个人"
    end
  end

  test "should handle voluntary assignment with volunteer assignments" do
    volunteer_assignments = {
      @schedule1.id => @user.id,
      @schedule2.id => @leader.id
    }

    service = LeaderAssignmentService.new(
      event: @reading_event,
      action: :auto_assign,
      assignment_options: {
        assignment_type: "voluntary",
        volunteer_assignments: volunteer_assignments
      }
    )

    result = service.call

    assert result.success?
    assert_equal "自愿分配完成", result.message
    assert_equal 2, result.data[:assigned_count]
    assert_equal @user, @schedule1.reload.daily_leader
    assert_equal @leader, @schedule2.reload.daily_leader
  end

  test "should reject auto-assignment for non-approved event" do
    @reading_event.update!(approval_status: "pending")

    service = LeaderAssignmentService.new(
      event: @reading_event,
      action: :auto_assign
    )

    result = service.call

    assert result.failure?
    assert_equal "活动未审批或没有日程安排", result.message
  end

  test "should reject auto-assignment when no participants available" do
    # 删除所有报名记录
    @reading_event.enrollments.delete_all

    service = LeaderAssignmentService.new(
      event: @reading_event,
      action: :auto_assign
    )

    result = service.call

    assert result.failure?
    assert_equal "没有参与者可供分配", result.message
  end

  test "should reject unsupported assignment type" do
    service = LeaderAssignmentService.new(
      event: @reading_event,
      action: :auto_assign,
      assignment_options: { assignment_type: "unsupported" }
    )

    result = service.call

    assert result.failure?
    assert_equal "不支持的分配方式: unsupported", result.message
  end

  test "should handle class method for auto-assignment" do
    participant = create_test_user(:user)
    EventEnrollment.create!(
      reading_event: @reading_event,
      user: participant,
      enrollment_type: "participant",
      status: "enrolled",
      enrollment_date: Time.current
    )

    result = LeaderAssignmentService.auto_assign_leaders!(@reading_event, assignment_type: "random")

    assert result.success?
    assert_equal "领读人分配完成", result.message
    assert_equal "random", result.data[:assignment_type]
  end

  # 补位分配测试
  test "should successfully handle backup assignment" do
    # 设置日程需要补位的情况
    @schedule1.update!(daily_leader: nil)

    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: @leader, # 活动创建者
      schedule: @schedule1,
      action: :backup_assign
    )

    result = service.call

    assert result.success?
    assert_equal "补位分配成功", result.message
    assert_equal @leader, @schedule1.reload.daily_leader

    schedule_data = result.data[:schedule]
    assert_equal @schedule1.id, schedule_data[:id]
    assert_equal 1, schedule_data[:day_number]

    leader_data = result.data[:backup_leader]
    assert_equal @leader.id, leader_data[:id]
    assert_equal @leader.nickname, leader_data[:nickname]
  end

  test "should reject backup assignment for non-creator" do
    other_user = create_test_user(:user)

    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: other_user,
      schedule: @schedule1,
      action: :backup_assign
    )

    result = service.call

    assert result.failure?
    assert_equal "只有活动创建者可以进行补位分配", result.message
  end

  test "should reject backup assignment when schedule not needed" do
    # 设置日程不需要补位的情况
    @schedule1.update!(daily_leader: @user)
    DailyLeading.create!(
      reading_schedule: @schedule1,
      leader: @user,
      content: "领读内容",
      published_at: Time.current
    )

    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: @leader,
      schedule: @schedule1,
      action: :backup_assign
    )

    result = service.call

    assert result.failure?
    assert_equal "该日程不需要补位", result.message
  end

  test "should handle class method for backup assignment" do
    @schedule1.update!(daily_leader: nil)

    result = LeaderAssignmentService.backup_assignment!(@reading_event, @schedule1, @leader)

    assert result.success?
    assert_equal "补位分配成功", result.message
    assert_equal @leader, @schedule1.reload.daily_leader
  end

  # 重新分配测试
  test "should successfully reassign leader" do
    original_leader = create_test_user(:user)
    @schedule1.update!(daily_leader: original_leader)

    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: @leader,
      schedule: @schedule1,
      action: :reassign
    )

    result = service.call

    assert result.success?
    assert_equal "领读人重新分配成功", result.message
    assert_equal @leader, @schedule1.reload.daily_leader

    old_leader_data = result.data[:old_leader]
    assert_equal original_leader.id, old_leader_data[:id]

    new_leader_data = result.data[:new_leader]
    assert_equal @leader.id, new_leader_data[:id]
  end

  test "should reject reassignment for unauthorized user" do
    original_leader = create_test_user(:user)
    @schedule1.update!(daily_leader: original_leader)

    unauthorized_user = create_test_user(:user)

    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: unauthorized_user,
      schedule: @schedule1,
      action: :reassign
    )

    result = service.call

    assert result.failure?
    assert_equal "权限不足", result.message
  end

  test "should handle class method for reassignment" do
    original_leader = create_test_user(:user)
    @schedule1.update!(daily_leader: original_leader)

    result = LeaderAssignmentService.reassign_leader!(@reading_event, @schedule1, @leader)

    assert result.success?
    assert_equal "领读人重新分配成功", result.message
    assert_equal @leader, @schedule1.reload.daily_leader
  end

  # 分配统计测试
  test "should get assignment statistics" do
    # 设置一些数据
    @schedule1.update!(daily_leader: @user)
    @schedule2.update!(daily_leader: @leader)

    DailyLeading.create!(
      reading_schedule: @schedule1,
      leader: @user,
      content: "领读内容",
      published_at: Time.current
    )

    service = LeaderAssignmentService.new(
      event: @reading_event,
      action: :get_statistics
    )

    result = service.call

    assert result.success?

    stats = result.data
    assert_equal 3, stats[:total_schedules]
    assert_equal 2, stats[:assigned_schedules]
    assert_equal 1, stats[:unassigned_schedules]
    assert_equal 2, stats[:unique_leaders]
    assert_equal 66.67, stats[:assignment_rate] # 2/3 * 100
    assert stats[:leader_workload].is_a?(Array)
    assert stats[:content_completion_rate] >= 0
  end

  test "should calculate leader workload statistics correctly" do
    @schedule1.update!(daily_leader: @user)
    @schedule2.update!(daily_leader: @user)
    @schedule3.update!(daily_leader: @leader)

    DailyLeading.create!(
      reading_schedule: @schedule1,
      leader: @user,
      content: "内容1",
      published_at: Time.current
    )

    service = LeaderAssignmentService.new(
      event: @reading_event,
      action: :get_statistics
    )

    result = service.call

    assert result.success?

    workloads = result.data[:leader_workload]
    user_workload = workloads.find { |w| w[:nickname] == @user.nickname }
    leader_workload = workloads.find { |w| w[:nickname] == @leader.nickname }

    assert_not_nil user_workload
    assert_equal 2, user_workload[:assigned_count]
    assert_equal 1, user_workload[:content_completed]

    assert_not_nil leader_workload
    assert_equal 1, leader_workload[:assigned_count]
    assert_equal 0, leader_workload[:content_completed]
  end

  test "should handle empty statistics for event with no schedules" do
    event_no_schedules = ReadingEvent.create!(
      title: "无日程活动",
      book_name: "测试书籍",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 20,
      leader: @leader,
      approval_status: "approved"
    )

    service = LeaderAssignmentService.new(
      event: event_no_schedules,
      action: :get_statistics
    )

    result = service.call

    assert result.success?

    stats = result.data
    assert_equal 0, stats[:total_schedules]
    assert_equal 0, stats[:assigned_schedules]
    assert_equal 0, stats[:unassigned_schedules]
    assert_equal 0, stats[:unique_leaders]
    assert_equal 0, stats[:assignment_rate]
    assert_equal [], stats[:leader_workload]
  end

  test "should handle class method for statistics" do
    @schedule1.update!(daily_leader: @user)

    result = LeaderAssignmentService.assignment_statistics(@reading_event)

    assert result.success?
    assert result.data.is_a?(Hash)
    assert result.data.key?(:total_schedules)
    assert result.data.key?(:assigned_schedules)
    assert result.data.key?(:assignment_rate)
  end

  # 权限检查测试
  test "should check leader permissions for enrolled user" do
    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: @user,
      schedule: @schedule1,
      action: :check_permissions
    )

    result = service.call

    assert result.success?

    permissions = result.data
    assert permissions[:can_view]
    assert permissions[:can_claim_leadership] # 因为是voluntary模式
    assert permissions[:can_be_assigned]
    assert_not permissions[:can_backup] # 只有创建者可以补位
    assert permissions[:current_schedules].is_a?(Array)
    assert permissions[:permission_window].is_a?(Hash)
  end

  test "should check permissions for non-enrolled user" do
    non_enrolled_user = create_test_user(:user)

    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: non_enrolled_user,
      action: :check_permissions
    )

    result = service.call

    assert result.success?
    assert_not result.data[:can_view]
    assert_equal "用户未报名活动", result.data[:message]
  end

  test "should check permissions for nil user" do
    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: nil,
      action: :check_permissions
    )

    result = service.call

    assert result.success?
    assert_not result.data[:can_view]
    assert_equal "用户不存在", result.data[:message]
  end

  test "should handle class method for permission check" do
    result = LeaderAssignmentService.check_permissions(@reading_event, @user, @schedule1)

    assert result.success?
    assert result.data[:can_view]
  end

  # 辅助方法测试
  test "should correctly identify available participants" do
    # 添加更多参与者
    participant1 = create_test_user(:user)
    participant2 = create_test_user(:user)
    leader_user = create_test_user(:user)

    [participant1, participant2, leader_user].each do |participant|
      EventEnrollment.create!(
        reading_event: @reading_event,
        user: participant,
        enrollment_type: "participant",
        status: "enrolled",
        enrollment_date: Time.current
      )
    end

    service = LeaderAssignmentService.new(event: @reading_event, action: :auto_assign)

    # 通过反射访问私有方法（仅用于测试）
    participants = service.send(:get_available_participants)

    assert participants.is_a?(Array)
    assert_includes participants, @user
    assert_includes participants, participant1
    assert_includes participants, participant2
    assert_includes participants, leader_user
  end

  test "should correctly check if user can be leader" do
    service = LeaderAssignmentService.new(event: @reading_event, user: @user)

    can_be_leader = service.send(:can_be_leader?, @user)
    assert can_be_leader

    non_enrolled_user = create_test_user(:user)
    can_be_leader = service.send(:can_be_leader?, non_enrolled_user)
    assert_not can_be_leader
  end

  test "should correctly check leadership claim permissions" do
    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: @user,
      schedule: @schedule1,
      action: :claim_leadership
    )

    can_claim = service.send(:can_claim_leadership?)
    assert can_claim

    # 当已有领读人时
    @schedule1.update!(daily_leader: @leader)
    can_claim = service.send(:can_claim_leadership?)
    assert_not can_claim
  end

  test "should correctly check backup assignment needs" do
    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: @leader,
      schedule: @schedule1,
      action: :backup_assign
    )

    # 无领读人时需要补位
    needs_backup = service.send(:schedule_needs_backup?, @schedule1)
    assert needs_backup

    # 有领读人但无内容时需要补位
    @schedule1.update!(daily_leader: @user)
    needs_backup = service.send(:schedule_needs_backup?, @schedule1)
    assert needs_backup

    # 有领读人和内容时不需要补位
    DailyLeading.create!(
      reading_schedule: @schedule1,
      leader: @user,
      content: "内容",
      published_at: Time.current
    )
    needs_backup = service.send(:schedule_needs_backup?, @schedule1)
    assert_not needs_backup
  end

  # 边界条件测试
  test "should handle assignment with no schedules" do
    event_no_schedules = ReadingEvent.create!(
      title: "无日程活动",
      book_name: "测试书籍",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 20,
      leader: @leader,
      approval_status: "approved"
    )

    service = LeaderAssignmentService.new(event: event_no_schedules, action: :auto_assign)

    result = service.call

    assert result.failure?
    assert_equal "活动未审批或没有日程安排", result.message
  end

  test "should handle assignment with single participant" do
    # 删除其他报名记录，只保留一个
    @reading_event.enrollments.where.not(user: @user).delete_all

    service = LeaderAssignmentService.new(
      event: @reading_event,
      action: :auto_assign,
      assignment_options: { assignment_type: "random" }
    )

    result = service.call

    assert result.success?
    assert_equal 3, result.data[:assigned_count]

    # 验证所有日程都分配给了同一个参与者
    leaders = @reading_event.reading_schedules.pluck(:daily_leader).uniq
    assert_equal 1, leaders.size
    assert_equal @user, leaders.first
  end

  test "should handle assignment with more schedules than participants" do
    # 创建更多日程
    10.times do |i|
      ReadingSchedule.create!(
        reading_event: @reading_event,
        date: Date.current + (8 + i).days,
        day_number: 4 + i,
        reading_progress: "第#{4 + i}章"
      )
    end

    service = LeaderAssignmentService.new(
      event: @reading_event,
      action: :auto_assign,
      assignment_options: { assignment_type: "random" }
    )

    result = service.call

    assert result.success?
    assert_equal 13, result.data[:assigned_count] # 3 + 10个日程

    # 验证所有日程都有领读人
    assert @reading_event.reading_schedules.where.not(daily_leader: nil).count == 13
  end

  # 性能测试
  test "should handle large event assignment efficiently" do
    # 创建大量日程
    100.times do |i|
      ReadingSchedule.create!(
        reading_event: @reading_event,
        date: Date.current + (8 + i).days,
        day_number: 1 + i,
        reading_progress: "第#{1 + i}章"
      )
    end

    # 创建多个参与者
    10.times do |i|
      participant = create_test_user(:user, nickname: "参与者#{i}")
      EventEnrollment.create!(
        reading_event: @reading_event,
        user: participant,
        enrollment_type: "participant",
        status: "enrolled",
        enrollment_date: Time.current
      )
    end

    service = LeaderAssignmentService.new(
      event: @reading_event,
      action: :auto_assign,
      assignment_options: { assignment_type: "random" }
    )

    start_time = Time.current
    result = service.call
    end_time = Time.current

    assert result.success?
    assert end_time - start_time < 5.seconds # 应该在5秒内完成
    assert_equal 103, result.data[:assigned_count] # 3 + 100个日程
  end

  # 错误处理测试
  test "should handle database errors gracefully" do
    # 模拟数据库错误（通过无效操作）
    invalid_schedule_id = 99999
    schedule = ReadingSchedule.new(id: invalid_schedule_id)

    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: @leader,
      schedule: schedule,
      action: :backup_assign
    )

    result = service.call

    assert result.failure?
    # 具体错误信息取决于实现
  end

  test "should handle invalid schedule in backup assignment" do
    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: @leader,
      schedule: nil,
      action: :backup_assign
    )

    result = service.call

    assert result.failure?
    assert_equal "补位需要指定日程和补位人", result.message
  end

  # 并发安全测试
  test "should handle concurrent assignment attempts" do
    service1 = LeaderAssignmentService.new(
      event: @reading_event,
      user: @user,
      schedule: @schedule1,
      action: :claim_leadership
    )

    service2 = LeaderAssignmentService.new(
      event: @reading_event,
      user: @leader,
      schedule: @schedule1,
      action: :claim_leadership
    )

    # 依次执行（真实并发需要线程）
    result1 = service1.call
    result2 = service2.call

    # 应该只有一个成功
    success_count = [result1.success?, result2.success?].count(true)
    failure_count = [result1.failure?, result2.failure?].count(true)

    assert_equal 1, success_count
    assert_equal 1, failure_count
  end

  # 集成测试
  test "should integrate with flower system" do
    @schedule1.update!(daily_leader: @user)

    # 创建小红花记录
    Flower.create!(
      giver: @leader,
      receiver: @user,
      reading_schedule: @schedule1,
      flower_type: "daily_leading",
      reason: "优秀领读"
    )

    service = LeaderAssignmentService.new(
      event: @reading_event,
      action: :get_statistics
    )

    result = service.call

    assert result.success?

    workloads = result.data[:leader_workload]
    user_workload = workloads.find { |w| w[:nickname] == @user.nickname }
    assert_equal 1, user_workload[:flowers_given]
  end

  test "should integrate with check-in system" do
    @schedule1.update!(daily_leader: @user)
    @schedule1.update!(date: Date.current) # 设为今天

    # 创建打卡记录
    CheckIn.create!(
      user: @leader,
      reading_schedule: @schedule1,
      content: "打卡内容",
      check_in_date: Date.current
    )

    service = LeaderAssignmentService.new(
      event: @reading_event,
      user: @leader,
      schedule: @schedule1,
      action: :backup_assign
    )

    # 由于有打卡但没有小红花，应该需要补位
    result = service.call

    assert result.success?
    assert_equal "补位分配成功", result.message
  end

  private

  def create_test_user(role = :user, **attributes)
    default_attrs = {
      wx_openid: "test_openid_#{SecureRandom.hex(4)}",
      nickname: "测试用户#{SecureRandom.hex(4)}",
      avatar_url: "https://example.com/avatar.jpg",
      created_at: Time.current,
      updated_at: Time.current
    }

    case role
    when :admin
      default_attrs[:role] = 1
    when :root
      default_attrs[:role] = 2
    else
      default_attrs[:role] = 0
    end

    User.create!(default_attrs.merge(attributes))
  end
end