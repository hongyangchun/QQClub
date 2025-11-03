# frozen_string_literal: true

require "test_helper"

class ActivityApprovalWorkflowServiceTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user(:user)
    @admin = create_test_user(:admin)
    @leader = create_test_user(:user)
    @root = create_test_user(:root)

    # 创建测试活动
    @reading_event = ReadingEvent.create!(
      title: "《红楼梦》精读班",
      book_name: "红楼梦",
      description: "一起精读中国古典名著红楼梦",
      start_date: Date.current + 14.days,
      end_date: Date.current + 21.days,
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

    # 创建阅读日程
    (Date.current + 14.days..Date.current + 21.days).each_with_index do |date, index|
      next if date.saturday? || date.sunday? # 跳过周末
      ReadingSchedule.create!(
        reading_event: @reading_event,
        date: date,
        day_number: index + 1,
        reading_progress: "第#{index + 1}章",
        reading_pages: "#{index * 10 + 1}-#{index * 10 + 10}"
      )
    end

    # 设置管理员权限（需要用户模型有can_approve_events?方法）
    # 这里假设用户模型已经实现了这些权限检查方法
  end

  # 提交审批测试
  test "should submit event for approval successfully" do
    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @leader,
      action: :submit_for_approval,
      workflow_type: :standard
    )

    result = service.call

    assert result.success?
    assert_equal "活动已提交审批，请等待管理员审核", result.message

    # 验证活动状态已更新
    @reading_event.reload
    assert_equal "draft", @reading_event.status
    assert_equal "pending", @reading_event.approval_status
    assert @reading_event.submitted_for_approval_at.present?
  end

  test "should fail submission when event cannot be submitted" do
    # 设置活动为已提交状态
    @reading_event.update!(submitted_for_approval_at: Time.current)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @leader,
      action: :submit_for_approval
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "活动当前状态无法提交审批"
  end

  test "should fail submission when event validation fails" do
    # 设置无效的活动数据
    @reading_event.update!(title: "", description: "")

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @leader,
      action: :submit_for_approval
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "活动标题不能为空"
    assert_includes result.error_messages, "活动描述不能为空"
  end

  test "should fail submission when event has no reading schedules" do
    # 删除所有阅读日程
    @reading_event.reading_schedules.destroy_all

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @leader,
      action: :submit_for_approval
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "必须设置阅读计划"
  end

  test "should handle invalid date range in event validation" do
    # 设置无效的开始日期
    @reading_event.update!(start_date: Date.current - 1.day)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @leader,
      action: :submit_for_approval
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "开始日期必须在今天之后"
  end

  test "should handle invalid participant numbers in event validation" do
    # 设置无效的参与人数
    @reading_event.update!(min_participants: 30, max_participants: 20)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @leader,
      action: :submit_for_approval
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "最小参与人数不能大于最大参与人数"
  end

  test "should validate paid events correctly" do
    # 设置收费活动但没有费用金额
    @reading_event.update!(fee_type: "paid", fee_amount: 0, leader_reward_percentage: nil)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @leader,
      action: :submit_for_approval
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "收费活动必须设置费用金额"
    assert_includes result.error_messages, "收费活动必须设置领读人奖励比例"
  end

  test "should validate video conference events correctly" do
    # 设置视频会议活动但没有会议链接
    @reading_event.update!(activity_mode: "video_conference", meeting_link: "")

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @leader,
      action: :submit_for_approval
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "视频会议活动必须设置会议链接"
  end

  test "should validate offline meeting events correctly" do
    # 设置线下活动但没有地点
    @reading_event.update!(activity_mode: "offline_meeting", location: "")

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @leader,
      action: :submit_for_approval
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "线下活动必须设置活动地点"
  end

  # 审批通过测试
  test "should approve event successfully with valid permissions" do
    # 先设置活动为待审批状态
    @reading_event.update!(approval_status: :pending)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @admin,
      action: :approve,
      approval_options: { reason: "活动内容完整，符合要求" }
    )

    result = service.call

    assert result.success?
    assert_equal "活动审批通过", result.message

    # 验证活动状态已更新
    @reading_event.reload
    assert_equal "enrolling", @reading_event.status
    assert_equal "approved", @reading_event.approval_status
    assert_equal @admin.id, @reading_event.approved_by_id
    assert @reading_event.approved_at.present?
    assert_equal "活动内容完整，符合要求", @reading_event.approval_reason
  end

  test "should fail approval when admin lacks permissions" do
    @reading_event.update!(approval_status: :pending)

    service = ActivityApprovalService.new(
      event: @reading_event,
      admin_user: @user, # 普通用户
      action: :approve
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "权限不足，无法审批活动"
  end

  test "should fail approval when event is not pending" do
    # 活动已经是草稿状态
    @reading_event.update!(approval_status: :draft)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @admin,
      action: :approve
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "活动当前状态无法审批"
  end

  test "should handle approval with reason and notes" do
    @reading_event.update!(approval_status: :pending)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @admin,
      action: :approve,
      approval_options: {
        reason: "活动内容丰富，适合推广",
        notes: "建议加强宣传，吸引更多参与者"
      }
    )

    result = service.call

    assert result.success?

    # 验证审批信息
    @reading_event.reload
    assert_equal "活动内容丰富，适合推广", @reading_event.approval_reason
    assert_equal "建议加强宣传，吸引更多参与者", @reading_event.approval_notes
  end

  # 审批拒绝测试
  test "should reject event successfully with valid reason" do
    @reading_event.update!(approval_status: :pending)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @admin,
      action: :reject,
      approval_options: { reason: "活动内容需要完善，请修改后重新提交" }
    )

    result = service.call

    assert result.success?
    assert_equal "活动已拒绝", result.message

    # 验证活动状态已更新
    @reading_event.reload
    assert_equal "rejected", @reading_event.approval_status
    assert_equal @admin.id, @reading_event.approved_by_id
    assert @reading_event.approved_at.present?
    assert_equal "活动内容需要完善，请修改后重新提交", @reading_event.rejection_reason
  end

  test "should fail rejection when reason is missing" do
    @reading_event.update!(approval_status: :pending)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @admin,
      action: :reject,
      approval_options: {}
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "请提供拒绝理由"
  end

  test "should fail rejection when admin lacks permissions" do
    @reading_event.update!(approval_status: :pending)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @user, # 普通用户
      action: :reject
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "权限不足，无法审批活动"
  end

  test "should allow resubmission after rejection" do
    # 先拒绝活动
    @reading_event.update!(
      approval_status: :rejected,
      rejection_reason: "需要修改"
    )

    # 重新提交应该成功
    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @leader,
      action: :submit_for_approval
    )

    result = service.call

    assert result.success?
  end

  # 批量审批测试
  test "should batch approve multiple events" do
    # 创建多个待审批的活动
    event1 = create_test_event("活动1", @leader)
    event2 = create_test_event("活动2", @admin)
    event3 = create_test_event("活动3", @user)

    # 设置为待审批状态
    [event1, event2, event3].each { |e| e.update!(approval_status: :pending) }

    service = ActivityApprovalWorkflowService.new(
      event: nil,
      admin_user: @admin,
      action: :batch_approve,
      approval_options: {
        event_ids: [event1.id, event2.id, event3.id],
        reason: "批量审批通过"
      }
    )

    result = service.call

    assert result.success?
    assert_includes result.message, "批量审批完成"

    # 验证结果统计
    summary = result.result[:summary]
    assert_equal 3, summary[:total]
    assert_equal 3, summary[:successful]
    assert_equal 0, summary[:failed]

    # 验证活动状态
    [event1, event2, event3].each do |event|
      event.reload
      assert_equal "approved", event.approval_status
      assert_equal @admin.id, event.approved_by_id
    end
  end

  test "should handle batch approval with some failures" do
    event1 = create_test_event("活动1", @leader)
    event2 = create_test_event("活动2", @admin)
    event3 = create_test_event("活动3", @user)

    # 设置event2为非待审批状态，这会导致失败
    event2.update!(approval_status: :approved)

    [event1, event3].each { |e| e.update!(approval_status: :pending) }

    service = ActivityApprovalWorkflowService.new(
      event: nil,
      admin_user: @admin,
      action: :batch_approve,
      approval_options: {
        event_ids: [event1.id, event2.id, event3.id],
        reason: "批量审批测试"
      }
    )

    result = service.call

    assert result.success?
    summary = result.result[:summary]
    assert_equal 3, summary[:total]
    assert_equal 2, summary[:successful]
    assert_equal 1, summary[:failed]

    # 验证失败的事件
    failed_events = result.result[:batch_results].select { |r| r[:success] == false }
    assert_equal 1, failed_events.length
    assert_equal event2.id, failed_events.first[:event_id]
  end

  test "should fail batch approval without permissions" do
    service = ActivityApprovalWorkflowService.new(
      event: nil,
      admin_user: @user, # 普通用户
      action: :batch_approve,
      approval_options: {
        event_ids: [@reading_event.id],
        reason: "测试批量审批"
      }
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "权限不足，无法批量审批活动"
  end

  test "should fail batch approval without valid event IDs" do
    service = ActivityApprovalService.new(
      event: nil,
      admin_user: @admin,
      action: :batch_approve,
      approval_options: {
        event_ids: [], # 空数组
        reason: "测试批量审批"
      }
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "请提供有效的活动ID列表"
  end

  test "should batch reject multiple events" do
    event1 = create_test_event("活动1", @leader)
    event2 = create_test_event("活动2", @admin)

    [event1, event2].each { |e| e.update!(approval_status: :pending) }

    service = ActivityApprovalWorkflowService.new(
      event: nil,
      admin_user: @admin,
      action: :batch_reject,
      approval_options: {
        event_ids: [event1.id, event2.id],
        reason: "批量拒绝测试"
      }
    )

    result = service.call

    assert result.success?
    assert_includes result.message, "批量拒绝完成"

    # 验证活动状态
    [event1, event2].each do |event|
      event.reload
      assert_equal "rejected", event.approval_status
      assert_equal "批量拒绝测试", event.rejection_reason
    end
  end

  # 审批队列测试
  test "should get approval queue with permissions" do
    # 创建多个待审批的活动
    events = []
    5.times do |i|
      event = create_test_event("活动#{i + 1}", @leader)
      event.update!(approval_status: :pending, submitted_for_approval_at: Time.current - i.hours)
      events << event
    end

    service = ActivityApprovalWorkflowService.new(
      event: nil,
      admin_user: @admin,
      action: :get_approval_queue,
      approval_options: {}
    )

    result = service.call

    assert result.success?

    queue = result.result[:approval_queue]
    assert_equal 5, queue.length

    # 验证排序（按提交时间）
    submission_times = queue.map { |item| item[:submitted_for_approval_at] }
    assert_equal submission_times.sort, submission_times

    # 验证包含必要信息
    queue.each do |item|
      assert item[:id]
      assert item[:title]
      assert item[:approval_status]
      assert item[:leader]
      assert item[:submitted_for_approval_at]
    end
  end

  test "should filter approval queue by parameters" do
    event1 = create_test_event("免费活动", @leader, fee_type: "free")
    event2 = create_test_event("收费活动", @admin, fee_type: "paid")
    event3 = create_test_event("视频活动", @user, activity_mode: "video_conference")

    [event1, event2, event3].each { |e| e.update!(approval_status: :pending) }

    # 按费用类型过滤
    service = ActivityApprovalWorkflowService.new(
      event: nil,
      admin_user: @admin,
      action: :get_approval_queue,
      approval_options: { fee_type: "free" }
    )

    result = service.call
    assert result.success?
    queue = result.result[:approval_queue]
    assert_equal 1, queue.length
    assert_equal "free", queue.first[:fee_type]

    # 按活动模式过滤
    service = ActivityApprovalWorkflowService.new(
      event: nil,
      admin_user: @admin,
      action: :get_approval_queue,
      approval_options: { activity_mode: "video_conference" }
    )

    result = service.call
    assert result.success?
    queue = result.result[:approval_queue]
    assert_equal 1, queue.length
    assert_equal "video_conference", queue.first[:activity_mode]
  end

  test "should paginate approval queue" do
    # 创建多个待审批的活动
    25.times do |i|
      event = create_test_event("活动#{i + 1}", @leader)
      event.update!(approval_status: :pending)
    end

    service = ActivityApprovalWorkflowService.new(
      event: nil,
      admin_user: @admin,
      action: :get_approval_queue,
      approval_options: { page: 1, per_page: 10 }
    )

    result = service.call

    assert result.success?
    queue = result.result[:approval_queue]
    assert_equal 10, queue.length # 每页10条

    pagination = result.result[:pagination]
    assert_equal 1, pagination[:current_page]
    assert_equal 10, pagination[:per_page]
    assert_equal 25, pagination[:total_count]
    assert_equal 3, pagination[:total_pages]
  end

  # 审批统计测试
  test "should get approval statistics with permissions" do
    # 创建不同状态的活动
    approved_events = []
    rejected_events = []
    pending_events = []

    # 已通过的活动
    5.times do |i|
      event = create_test_event("已批准活动#{i + 1}", @leader)
      event.update!(approval_status: :approved, approved_at: Date.current - i.days)
      approved_events << event
    end

    # 已拒绝的活动
    3.times do |i|
      event = create_test_event("已拒绝活动#{i + 1}", @admin)
      event.update!(approval_status: :rejected, approved_at: Date.current - i.days)
      rejected_events << event
    end

    # 待审批的活动
    2.times do |i|
      event = create_test_event("待审批活动#{i + 1}", @user)
      event.update!(approval_status: :pending)
      pending_events << event
    end

    service = ActivityApprovalWorkflowService.new(
      event: nil,
      admin_user: @admin,
      action: :get_approval_statistics,
      approval_options: {}
    )

    result = service.call

    assert result.success?

    stats = result.result
    assert_equal 2, stats[:total_pending]
    assert_equal 5, stats[:total_approved]
    assert_equal 3, stats[:total_rejected]
    assert stats[:average_approval_time].present?
    assert stats[:approval_rate].present?
    assert stats[:admin_stats].is_a?(Array)
    assert stats[:activity_mode_stats].is_a?(Hash)
  end

  test "should calculate approval statistics correctly" do
    # 创建已知审批时间的活动
    event1 = create_test_event("活动1", @leader)
    event2 = create_test_event("活动2", @admin)

    # 设置已知的提交和审批时间
    event1.update!(
      approval_status: :approved,
      submitted_for_approval_at: Time.current - 2.days,
      approved_at: Time.current - 1.day
    )

    event2.update!(
      approval_status: :approved,
      submitted_for_approval_at: Time.current - 4.days,
      approved_at: Time.current - 2.days
    )

    service = ActivityApprovalWorkflowService.new(
      event: nil,
      admin_user: @admin,
      action: :get_approval_statistics,
      approval_options: {
        date_range: (Date.current - 5.days)..Date.current
      }
    )

    result = service.call

    assert result.success?
    stats = result.result

    # 验证平均审批时间计算
    # event1: 1天前 (24小时)
    # event2: 2天前 (48小时)
    # 平均: (24 + 48) / 2 = 36小时 = 1.5天
    assert_equal 1.5, stats[:average_approval_time]
  end

  # 升级审批测试
  test "should escalate approval successfully" do
    @reading_event.update!(approval_status: :pending)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @admin,
      action: :escalate,
      approval_options: {
        escalation_reason: "需要高级管理员审批此活动"
      }
    )

    result = service.call

    assert result.success?
    assert_equal "审批已升级给高级管理员", result.message

    escalation_details = result.result[:escalation_details]
    assert_equal "需要高级管理员审批此活动", escalation_details[:reason]
    assert_equal @admin.id, escalation_details[:escalated_by][:id]
  end

  test "should fail escalation when event is not pending" do
    @reading_event.update!(approval_status: :approved)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @admin,
      action: :escalate
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "只有待审批的活动可以升级审批"
  end

  test "should fail escalation without reason" do
    @reading_event.update!(approval_status: :pending)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @admin,
      action: :escalate
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "请提供升级理由"
  end

  # 边界条件测试
  test "should handle service initialization errors gracefully" do
    # 测试nil event
    service = ActivityApprovalWorkflowService.new(
      event: nil,
      admin_user: @admin,
      action: :approve
    )

    # 尝试不支持的action
    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @admin,
      action: :unsupported_action
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "不支持的审批操作: unsupported_action"
  end

  test "should handle database errors gracefully" do
    # 模拟数据库错误
    @reading_event.stub(:save!).raises(ActiveRecord::RecordInvalid)

    service = ActivityApprovalWorkflowService.new(
      event: @reading_event,
      admin_user: @leader,
      action: :submit_for_approval
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "提交审批失败"
  end

  test "should handle concurrent approval requests" do
    @reading_event.update!(approval_status: :pending)

    # 模拟并发审批
    threads = []
    results = []

    3.times do |i|
      threads << Thread.new do
        service = ActivityApprovalWorkflowService.new(
          event: @reading_event,
          admin_user: @admin,
          action: :approve,
          approval_options: { reason: "并发审批#{i}" }
        )
        results << service.call
      end
    end

    threads.each(&:join)

    # 验证只有一个审批成功
    success_count = results.count(&:success?)
    failed_count = results.count { |r| !r.success? }

    assert_equal 1, success_count
    assert_equal 2, failed_count

    # 验证活动状态一致性
    @reading_event.reload
    assert_equal "approved", @reading_event.approval_status
  end

  test "should handle transaction rollback on approval failure" do
    # 创建会在审批时失败的活动
    invalid_event = create_test_event("无效活动", @leader)
    invalid_event.update!(approval_status: :pending)

    # 让审批失败
    invalid_event.stub(:update!).raises(StandardError, "审批失败")

    service = ActivityApprovalWorkflowService.new(
      event: invalid_event,
      admin_user: @admin,
      action: :approve
    )

    result = service.call

    assert_not result.success?
    assert_includes result.error_messages, "审批通过失败"

    # 验证事务已回滚
    invalid_event.reload
    assert_equal "pending", invalid_event.approval_status
  end

  # 类方法测试
  test "should submit for approval using class method" do
    service = ActivityApprovalWorkflowService.submit_for_approval!(@reading_event)

    assert service.success?
    assert_equal "活动已提交审批，请等待管理员审核", service.message

    @reading_event.reload
    assert_equal "pending", @reading_event.approval_status
  end

  test "should approve using class method" do
    @reading_event.update!(approval_status: :pending)

    service = ActivityApprovalWorkflowService.approve!(@reading_event, @admin, "测试审批")

    assert service.success?
    assert_equal "活动审批通过", service.message

    @reading_event.reload
    assert_equal "approved", @reading_event.approval_status
  end

  test "should reject using class method" do
    @reading_event.update!(approval_status: :pending)

    service = ActivityApprovalWorkflowService.reject!(@reading_event, @admin, "测试拒绝")

    assert service.success?
    assert_equal "活动已拒绝", service.message

    @reading_event.reload
    assert_equal "rejected", @reading_event.approval_status
    assert_equal "测试拒绝", @reading_event.rejection_reason
  end

  test "should batch approve using class method" do
    event1 = create_test_event("批量活动1", @leader)
    event2 = create_test_event("批量活动2", @admin)

    [event1, event2].each { |e| e.update!(approval_status: :pending) }

    service = ActivityApprovalWorkflowService.batch_approve!(
      [event1.id, event2.id],
      @admin,
      "批量类方法测试"
    )

    assert service.success?
    assert_includes service.message, "批量审批完成"

    [event1, event2].each do |event|
      event.reload
      assert_equal "approved", event.approval_status
    end
  end

  test "should get approval queue using class method" do
    3.times do |i|
      event = create_test_event("队列活动#{i + 1}", @leader)
      event.update!(approval_status: :pending)
    end

    service = ActivityApprovalWorkflowService.approval_queue(@admin)

    assert service.success?
    assert service.result[:approval_queue].is_a?(Array)
    assert_equal 3, service.result[:approval_queue].length
  end

  test "should get approval statistics using class method" do
    service = ActivityApprovalWorkflowService.approval_statistics(@admin)

    assert service.success?
    stats = service.result
    assert stats[:total_pending].is_a?(Integer)
    assert stats[:total_approved].is_a?(Integer)
    assert stats[:total_rejected].is_a?(Integer)
  end

  test "should escalate using class method" do
    @reading_event.update!(approval_status: :pending)

    service = ActivityApprovalWorkflowService.escalate!(
      @reading_event,
      @admin,
      "类方法升级测试"
    )

    assert service.success?
    assert_equal "审批已升级给高级管理员", service.message

    escalation_details = service.result[:escalation_details]
    assert_equal "类方法升级测试", escalation_details[:reason]
  end

  private

  def create_test_event(title, leader, **overrides)
    default_attrs = {
      title: title,
      book_name: "测试书籍",
      description: "测试描述",
      start_date: Date.current + 14.days,
      end_date: Date.current + 21.days,
      max_participants: 20,
      min_participants: 5,
      fee_type: "free",
      fee_amount: 0,
      leader_reward_percentage: 0,
      completion_standard: 80,
      activity_mode: "note_checkin",
      leader_assignment_type: "voluntary",
      weekend_rest: true,
      leader: leader
    }

    ReadingEvent.create!(default_attrs.merge(overrides))
  end
end