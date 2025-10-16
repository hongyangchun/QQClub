# frozen_string_literal: true

require "test_helper"

class EventManagementServiceTest < ActiveSupport::TestCase
  def setup
    @admin = create_test_user(:admin)
    @regular_user = create_test_user(:user)
    @event = create_test_reading_event(leader: @regular_user)
  end

  # 活动审批测试
  test "should approve event successfully with admin user" do
    service = EventManagementService.new(event: @event, admin_user: @admin, action: :approve)
    result = service.call

    assert result.success?
    assert_equal "活动审批通过", result.result[:message]
    assert_equal :approved, @event.reload.approval_status_symbol
    assert_equal @admin.id, @event.approved_by_id
    assert_not_nil @event.approved_at
  end

  test "should fail approval when user is not admin" do
    service = EventManagementService.new(event: @event, admin_user: @regular_user, action: :approve)
    result = service.call

    assert result.failure?
    assert result.error_messages.any? { |msg| msg.include?("没有审批权限") }
    assert_equal :pending, @event.reload.approval_status_symbol
  end

  test "should fail approval when event is not pending" do
    @event.update!(approval_status: :approved)

    service = EventManagementService.new(event: @event, admin_user: @admin, action: :approve)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "只能审批待审批的活动"
  end

  test "should fail approval when admin user is nil" do
    service = EventManagementService.new(event: @event, admin_user: nil, action: :approve)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "管理员用户不能为空"
  end

  # 活动拒绝测试
  test "should reject event successfully with admin user" do
    service = EventManagementService.new(event: @event, admin_user: @admin, action: :reject)
    result = service.call

    assert result.success?
    assert_equal "活动已被拒绝", result.result[:message]
    assert_equal :rejected, @event.reload.approval_status_symbol
    assert_equal @admin.id, @event.approved_by_id
    assert_not_nil @event.approved_at
  end

  test "should fail rejection when user is not admin" do
    service = EventManagementService.new(event: @event, admin_user: @regular_user, action: :reject)
    result = service.call

    assert result.failure?
    assert result.error_messages.any? { |msg| msg.include?("没有审批权限") }
  end

  # 活动完成测试
  test "should complete event successfully with current leader" do
    @event.update!(status: :in_progress, leader: @admin)

    service = EventManagementService.new(event: @event, admin_user: @admin, action: :complete)
    result = service.call

    assert result.success?
    assert_equal "活动已成功结束", result.result[:message]
    assert_equal :completed, @event.reload.status_symbol
  end

  test "should fail completion when user is not current leader" do
    # 创建一个以admin为leader的活动
    other_event = create_test_reading_event(leader: @admin)
    other_event.update!(status: :in_progress)

    service = EventManagementService.new(event: other_event, admin_user: @regular_user, action: :complete)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "只有活动小组长可以结束活动"
  end

  test "should fail completion when event is already completed" do
    @event.update!(status: :completed, leader: @admin)

    service = EventManagementService.new(event: @event, admin_user: @admin, action: :complete)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "活动已经结束"
  end

  # 类方法测试
  test "should approve event using class method" do
    result = EventManagementService.approve_event!(@event, @admin)

    assert result.success?
    assert_equal :approved, @event.reload.approval_status_symbol
  end

  test "should reject event using class method" do
    result = EventManagementService.reject_event!(@event, @admin)

    assert result.success?
    assert_equal :rejected, @event.reload.approval_status_symbol
  end

  test "should complete event using class method" do
    @event.update!(status: :in_progress, leader: @admin)

    result = EventManagementService.complete_event!(@event, @admin)

    assert result.success?
    assert_equal :completed, @event.reload.status_symbol
  end

  # 随机分配功能测试
  test "should auto-assign leaders when approving event with random assignment" do
    @event.update!(leader_assignment_type: 'random')

    # 添加参与者
    participant1 = create_test_user(:user)
    participant2 = create_test_user(:user)
    create_test_enrollment(reading_event: @event, user: participant1)
    create_test_enrollment(reading_event: @event, user: participant2)

    service = EventManagementService.approve_event!(@event, @admin)

    assert service.success?
    # 验证已分配领读人
    @event.reading_schedules.each do |schedule|
      assert_not_nil schedule.daily_leader_id
    end
  end

  
  # 边界条件测试
  test "should handle unsupported action" do
    service = EventManagementService.new(event: @event, admin_user: @admin, action: :unsupported)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "不支持的操作: unsupported"
  end
end