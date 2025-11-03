# frozen_string_literal: true

# ActivityApprovalWorkflowService - 活动审批工作流服务
# 负责活动审批的完整业务流程，包括多级审批、条件检查、通知等
class ActivityApprovalWorkflowService < ApplicationService
  attr_reader :event, :admin_user, :action, :approval_options, :workflow_type

  def initialize(event:, admin_user:, action:, workflow_type: :standard, approval_options: {})
    super()
    @event = event
    @admin_user = admin_user
    @action = action
    @workflow_type = workflow_type
    @approval_options = approval_options ? approval_options.with_indifferent_access : {}.with_indifferent_access
  end

  def call
    handle_errors do
      case action
      when :submit_for_approval
        submit_for_approval
      when :approve
        process_approval
      when :reject
        process_rejection
      when :batch_approve
        batch_approve_events
      when :batch_reject
        batch_reject_events
      when :get_approval_queue
        get_approval_queue
      when :get_approval_statistics
        get_approval_statistics
      when :escalate
        escalate_approval
      else
        failure!("不支持的审批操作: #{action}")
      end
    end

    self
  end

  # 类方法：提交审批
  def self.submit_for_approval!(event, workflow_type: :standard)
    service = new(event: event, admin_user: event.leader, action: :submit_for_approval, workflow_type: workflow_type)
    service.call
    service
  end

  # 类方法：审批通过
  def self.approve!(event, admin_user, reason: nil, notes: nil)
    service = new(event: event, admin_user: admin_user, action: :approve,
                  approval_options: { reason: reason, notes: notes })
    service.call
    service
  end

  # 类方法：审批拒绝
  def self.reject!(event, admin_user, reason, notes: nil)
    service = new(event: event, admin_user: admin_user, action: :reject,
                  approval_options: { reason: reason, notes: notes })
    service.call
    service
  end

  # 类方法：批量审批
  def self.batch_approve!(event_ids, admin_user, reason: nil)
    service = new(event: nil, admin_user: admin_user, action: :batch_approve,
                  approval_options: { event_ids: event_ids, reason: reason })
    service.call
    service
  end

  # 类方法：批量拒绝
  def self.batch_reject!(event_ids, admin_user, reason)
    service = new(event: nil, admin_user: admin_user, action: :batch_reject,
                  approval_options: { event_ids: event_ids, reason: reason })
    service.call
    service
  end

  # 类方法：获取审批队列
  def self.approval_queue(admin_user, filters = {})
    service = new(event: nil, admin_user: admin_user, action: :get_approval_queue,
                  approval_options: filters)
    service.call
    service
  end

  # 类方法：获取审批统计
  def self.approval_statistics(admin_user, date_range: nil)
    service = new(event: nil, admin_user: admin_user, action: :get_approval_statistics,
                  approval_options: { date_range: date_range })
    service.call
    service
  end

  # 类方法：升级审批
  def self.escalate!(event, admin_user, escalation_reason)
    service = new(event: event, admin_user: admin_user, action: :escalate,
                   approval_options: { escalation_reason: escalation_reason })
    service.call
    service
  end

  private

  # 提交审批申请
  def submit_for_approval
    # 检查是否可以提交审批
    unless event.can_submit_for_approval?
      return failure!("活动当前状态无法提交审批")
    end

    # 检查审批前置条件
    validation_result = validate_event_for_approval
    unless validation_result[:valid]
      return failure!(validation_result[:errors].join(", "))
    end

    ActiveRecord::Base.transaction do
      # 更新活动状态为待审批
      event.update!(
        status: :draft,
        approval_status: :pending,
        submitted_for_approval_at: Time.current
      )

      # 记录审批日志
      create_approval_log(:submitted, event.leader, "提交审批申请")

      # 发送通知给审批管理员（暂时注释，等待通知系统实现）
      # send_approval_notifications

      success!({
        message: "活动已提交审批，请等待管理员审核",
        event: event_approval_info,
        approval_queue_position: get_approval_queue_position
      })
    end
  rescue => e
    failure!("提交审批失败: #{e.message}")
  end

  # 处理审批通过
  def process_approval
    # 检查审批权限
    unless admin_user.can_approve_events?
      return failure!("权限不足，无法审批活动")
    end

    # 检查活动状态
    unless event.pending_approval?
      return failure!("活动当前状态无法审批")
    end

    # 执行审批通过流程
    ActiveRecord::Base.transaction do
      # 更新活动状态
      event.update!(
        status: :enrolling,
        approval_status: :approved,
        approved_by_id: admin_user.id,
        approved_at: Time.current,
        approval_reason: @approval_options[:reason],
        approval_notes: @approval_options[:notes]
      )

      # 记录审批日志
      create_approval_log(:approved, admin_user, @approval_options[:reason])

      # 发送审批通过通知
      send_approval_decision_notification(:approved)

      success!({
        message: "活动审批通过",
        event: event_approval_info,
        approval_details: approval_decision_info
      })
    end
  rescue => e
    failure!("审批通过失败: #{e.message}")
  end

  # 处理审批拒绝
  def process_rejection
    # 检查审批权限
    unless admin_user.can_approve_events?
      return failure!("权限不足，无法审批活动")
    end

    # 检查拒绝理由
    rejection_reason = @approval_options[:reason]
    if rejection_reason.blank?
      return failure!("请提供拒绝理由")
    end

    # 检查活动状态
    unless event.pending_approval?
      return failure!("活动当前状态无法审批")
    end

    ActiveRecord::Base.transaction do
      # 更新活动状态
      event.update!(
        approval_status: :rejected,
        approved_by_id: admin_user.id,
        approved_at: Time.current,
        rejection_reason: rejection_reason,
        approval_notes: @approval_options[:notes]
      )

      # 记录审批日志
      create_approval_log(:rejected, admin_user, rejection_reason)

      # 发送审批拒绝通知
      send_approval_decision_notification(:rejected)

      success!({
        message: "活动已拒绝",
        event: event_approval_info,
        rejection_details: {
          reason: rejection_reason,
          notes: @approval_options[:notes],
          resubmission_allowed: event.can_resubmit_for_approval?
        }
      })
    end
  rescue => e
    failure!("审批拒绝失败: #{e.message}")
  end

  # 批量审批通过
  def batch_approve_events
    unless admin_user.can_approve_events?
      return failure!("权限不足，无法批量审批活动")
    end

    event_ids = @approval_options[:event_ids]
    if event_ids.blank? || !event_ids.is_a?(Array)
      return failure!("请提供有效的活动ID列表")
    end

    events = ReadingEvent.where(id: event_ids, approval_status: :pending)
    if events.empty?
      return failure!("没有找到待审批的活动")
    end

    approval_results = []
    failed_count = 0

    ActiveRecord::Base.transaction do
      events.each do |event_item|
        begin
          event_item.update!(
            status: :enrolling,
            approval_status: :approved,
            approved_by_id: admin_user.id,
            approved_at: Time.current,
            approval_reason: @approval_options[:reason]
          )

          create_approval_log(:approved, admin_user, @approval_options[:reason], event_item)
          approval_results << { event_id: event_item.id, status: 'approved', success: true }
        rescue => e
          failed_count += 1
          approval_results << { event_id: event_item.id, status: 'failed', error: e.message, success: false }
        end
      end
    end

    success!({
      message: "批量审批完成，成功: #{events.count - failed_count}，失败: #{failed_count}",
      batch_results: approval_results,
      summary: {
        total: events.count,
        successful: events.count - failed_count,
        failed: failed_count
      }
    })
  rescue => e
    failure!("批量审批失败: #{e.message}")
  end

  # 批量审批拒绝
  def batch_reject_events
    unless admin_user.can_approve_events?
      return failure!("权限不足，无法批量审批活动")
    end

    rejection_reason = @approval_options[:reason]
    if rejection_reason.blank?
      return failure!("请提供拒绝理由")
    end

    event_ids = @approval_options[:event_ids]
    if event_ids.blank? || !event_ids.is_a?(Array)
      return failure!("请提供有效的活动ID列表")
    end

    events = ReadingEvent.where(id: event_ids, approval_status: :pending)
    if events.empty?
      return failure!("没有找到待审批的活动")
    end

    rejection_results = []
    failed_count = 0

    ActiveRecord::Base.transaction do
      events.each do |event_item|
        begin
          event_item.update!(
            approval_status: :rejected,
            approved_by_id: admin_user.id,
            approved_at: Time.current,
            rejection_reason: rejection_reason,
            approval_notes: @approval_options[:notes]
          )

          create_approval_log(:rejected, admin_user, rejection_reason, event_item)
          rejection_results << { event_id: event_item.id, status: 'rejected', success: true }
        rescue => e
          failed_count += 1
          rejection_results << { event_id: event_item.id, status: 'failed', error: e.message, success: false }
        end
      end
    end

    success!({
      message: "批量拒绝完成，成功: #{events.count - failed_count}，失败: #{failed_count}",
      batch_results: rejection_results,
      summary: {
        total: events.count,
        successful: events.count - failed_count,
        failed: failed_count
      }
    })
  rescue => e
    failure!("批量拒绝失败: #{e.message}")
  end

  # 获取审批队列
  def get_approval_queue
    # 检查查看权限
    unless admin_user.can_approve_events? || admin_user.can_view_approval_queue?
      return failure!("权限不足，无法查看审批队列")
    end

    filters = @approval_options
    events = ReadingEvent.includes(:leader).where(approval_status: :pending)

    # 应用过滤条件
    events = apply_approval_queue_filters(events, filters)

    # 排序
    events = events.order(submitted_for_approval_at: :asc)

    # 分页
    page = filters[:page] || 1
    per_page = filters[:per_page] || 20
    total_count = events.count
    paginated_events = events.limit(per_page).offset((page - 1) * per_page)

    queue_data = paginated_events.map do |event_item|
      event_approval_queue_info(event_item)
    end

    success!({
      approval_queue: queue_data,
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      },
      filters_applied: filters,
      queue_statistics: get_queue_statistics(events)
    })
  end

  # 获取审批统计
  def get_approval_statistics
    unless admin_user.can_approve_events?
      return failure!("权限不足，无法查看审批统计")
    end

    date_range = @approval_options[:date_range] || (Date.today - 30.days)..Date.today

    stats = {
      total_pending: ReadingEvent.where(approval_status: :pending).count,
      total_approved: ReadingEvent.where(approval_status: :approved).count,
      total_rejected: ReadingEvent.where(approval_status: :rejected).count,

      # 期间统计
      period_approved: ReadingEvent.where(approval_status: :approved, approved_at: date_range).count,
      period_rejected: ReadingEvent.where(approval_status: :rejected, approved_at: date_range).count,

      # 审批效率统计
      average_approval_time: calculate_average_approval_time(date_range),
      approval_rate: calculate_approval_rate(date_range),

      # 管理员统计
      admin_stats: get_admin_approval_stats(date_range),

      # 活动类型统计
      activity_mode_stats: get_activity_mode_approval_stats(date_range)
    }

    success!(stats)
  end

  # 升级审批
  def escalate_approval
    unless event.pending_approval?
      return failure!("只有待审批的活动可以升级审批")
    end

    escalation_reason = @approval_options[:escalation_reason]
    if escalation_reason.blank?
      return failure!("请提供升级理由")
    end

    ActiveRecord::Base.transaction do
      # 记录升级日志
      create_approval_log(:escalated, admin_user, escalation_reason)

      # 发送升级通知给高级管理员
      send_escalation_notification(escalation_reason)

      success!({
        message: "审批已升级给高级管理员",
        event: event_approval_info,
        escalation_details: {
          reason: escalation_reason,
          escalated_by: admin_user_info,
          escalated_at: Time.current
        }
      })
    end
  rescue => e
    failure!("升级审批失败: #{e.message}")
  end

  # 辅助方法

  # 验证活动是否满足审批条件
  def validate_event_for_approval
    errors = []

    # 检查基本信息
    errors << "活动标题不能为空" if event.title.blank?
    errors << "活动描述不能为空" if event.description.blank?
    errors << "书籍名称不能为空" if event.book_name.blank?

    # 检查日期设置
    errors << "开始日期不能为空" if event.start_date.blank?
    errors << "结束日期不能为空" if event.end_date.blank?
    errors << "开始日期必须在今天之后" if event.start_date <= Date.today

    # 检查人数设置
    errors << "最大参与人数必须大于0" if event.max_participants.nil? || event.max_participants <= 0
    errors << "最小参与人数不能大于最大参与人数" if event.min_participants > event.max_participants

    # 检查费用设置（如果是收费活动）
    if event.fee_type != 'free'
      errors << "收费活动必须设置费用金额" if event.fee_amount.nil? || event.fee_amount <= 0
      errors << "收费活动必须设置领读人奖励比例" if event.leader_reward_percentage.nil?
    end

    # 检查阅读计划
    if event.reading_schedules.empty?
      errors << "必须设置阅读计划"
    end

    # 检查特定活动模式的特殊要求
    case event.activity_mode
    when 'video_conference'
      errors << "视频会议活动必须设置会议链接" if event.meeting_link.blank?
    when 'offline_meeting'
      errors << "线下活动必须设置活动地点" if event.location.blank?
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  # 应用审批队列过滤条件
  def apply_approval_queue_filters(events, filters)
    events = events.where(leader_id: filters[:leader_id]) if filters[:leader_id].present?
    events = events.where(activity_mode: filters[:activity_mode]) if filters[:activity_mode].present?
    events = events.where(fee_type: filters[:fee_type]) if filters[:fee_type].present?
    events = events.where('submitted_for_approval_at >= ?', filters[:submitted_since]) if filters[:submitted_since].present?
    events = events.where('submitted_for_approval_at <= ?', filters[:submitted_until]) if filters[:submitted_until].present?

    events
  end

  # 计算平均审批时间
  def calculate_average_approval_time(date_range)
    approved_events = ReadingEvent.where(
      approval_status: :approved,
      approved_at: date_range
    ).where.not(submitted_for_approval_at: nil)

    return 0 if approved_events.empty?

    total_time = approved_events.sum do |event|
      (event.approved_at - event.submitted_for_approval_at) / 1.hour
    end

    (total_time / approved_events.count).round(2)
  end

  # 计算审批通过率
  def calculate_approval_rate(date_range)
    total_events = ReadingEvent.where(
      approved_at: date_range
    ).where.not(approval_status: :pending)

    return 0 if total_events.empty?

    approved_count = total_events.where(approval_status: :approved).count
    (approved_count.to_f / total_events.count * 100).round(2)
  end

  # 获取管理员审批统计
  def get_admin_approval_stats(date_range)
    approved_events = ReadingEvent.includes(:approver)
      .where(approval_status: :approved, approved_at: date_range)
      .where.not(approved_by_id: nil)

    stats = {}
    approved_events.each do |event|
      admin_id = event.approved_by_id
      stats[admin_id] ||= {
        name: event.approver&.nickname || 'Unknown',
        approved_count: 0,
        rejected_count: 0
      }
      stats[admin_id][:approved_count] += 1
    end

    rejected_events = ReadingEvent.includes(:approver)
      .where(approval_status: :rejected, approved_at: date_range)
      .where.not(approved_by_id: nil)

    rejected_events.each do |event|
      admin_id = event.approved_by_id
      stats[admin_id] ||= {
        name: event.approver&.nickname || 'Unknown',
        approved_count: 0,
        rejected_count: 0
      }
      stats[admin_id][:rejected_count] += 1
    end

    stats.values
  end

  # 获取活动模式审批统计
  def get_activity_mode_approval_stats(date_range)
    modes = %w[note_checkin free_discussion video_conference offline_meeting]
    stats = {}

    modes.each do |mode|
      total = ReadingEvent.where(
        activity_mode: mode,
        approved_at: date_range
      ).where.not(approval_status: :pending).count

      approved = ReadingEvent.where(
        activity_mode: mode,
        approval_status: :approved,
        approved_at: date_range
      ).count

      stats[mode] = {
        total: total,
        approved: approved,
        rejected: total - approved,
        approval_rate: total > 0 ? (approved.to_f / total * 100).round(2) : 0
      }
    end

    stats
  end

  # 获取队列统计信息
  def get_queue_statistics(events)
    {
      total_pending: events.count,
      pending_by_fee_type: events.group(:fee_type).count,
      pending_by_activity_mode: events.group(:activity_mode).count,
      oldest_pending_age: events.maximum(:submitted_for_approval_at) ?
        ((Time.current - events.maximum(:submitted_for_approval_at)) / 1.day).round(1) : 0,
      average_pending_age: events.average(:submitted_for_approval_at) ?
        ((Time.current - events.average(:submitted_for_approval_at)) / 1.day).round(1) : 0
    }
  end

  # 创建审批日志
  def create_approval_log(action, operator, reason, target_event = event)
    # 这里应该创建一个 ApprovalLog 模型来记录审批历史
    # 暂时使用 Rails logger 记录
    Rails.logger.info "审批日志: #{action} - 活动 #{target_event.id} - 操作者 #{operator.nickname} - 理由: #{reason}"
  end

  # 发送审批决定通知
  def send_approval_decision_notification(decision)
    # 这里应该实现通知系统
    Rails.logger.info "审批通知: 活动 #{event.id} 已被#{decision == :approved ? '通过' : '拒绝'}"
  end

  # 发送升级通知
  def send_escalation_notification(reason)
    # 这里应该实现升级通知给高级管理员
    Rails.logger.info "审批升级: 活动 #{event.id} 需要高级管理员审批 - 理由: #{reason}"
  end

  # 获取审批队列位置
  def get_approval_queue_position
    ReadingEvent.where(approval_status: :pending)
      .where('submitted_for_approval_at <= ?', event.submitted_for_approval_at)
      .count
  end

  # 格式化活动审批信息
  def event_approval_info
    {
      id: event.id,
      title: event.title,
      book_name: event.book_name,
      activity_mode: event.activity_mode,
      fee_type: event.fee_type,
      fee_amount: event.fee_amount,
      max_participants: event.max_participants,
      start_date: event.start_date,
      end_date: event.end_date,
      leader: user_info(event.leader),
      status: event.status,
      approval_status: event.approval_status,
      submitted_for_approval_at: event.submitted_for_approval_at,
      approved_at: event.approved_at,
      approver: event.approver ? user_info(event.approver) : nil
    }
  end

  # 格式化活动审批队列信息
  def event_approval_queue_info(event_item)
    {
      id: event_item.id,
      title: event_item.title,
      book_name: event_item.book_name,
      activity_mode: event_item.activity_mode,
      fee_type: event_item.fee_type,
      fee_amount: event_item.fee_amount,
      max_participants: event_item.max_participants,
      start_date: event_item.start_date,
      end_date: event_item.end_date,
      leader: user_info(event_item.leader),
      submitted_for_approval_at: event_item.submitted_for_approval_at,
      pending_age_days: event_item.submitted_for_approval_at ?
        ((Time.current - event_item.submitted_for_approval_at) / 1.day).round(1) : 0,
      validation_status: event_item.validate_event_for_approval[:valid] ? 'valid' : 'invalid',
      requires_attention: requires_immediate_attention?(event_item)
    }
  end

  # 格式化审批决定信息
  def approval_decision_info
    {
      approved_by: user_info(admin_user),
      approved_at: Time.current,
      reason: @approval_options[:reason],
      notes: @approval_options[:notes],
      next_steps: get_next_steps_after_approval
    }
  end

  # 获取审批后的下一步操作
  def get_next_steps_after_approval
    if @action == :approve
      [
        "活动已进入报名状态",
        "系统已自动通知活动创建者",
        "参与者现在可以报名参加活动",
        "活动将在开始日期自动开始"
      ]
    else
      [
        "活动已被拒绝",
        "创建者可以根据拒绝理由修改活动",
        "修改后可以重新提交审批"
      ]
    end
  end

  # 检查活动是否需要立即关注
  def requires_immediate_attention?(event_item)
    # 检查是否即将开始
    return true if event_item.start_date && event_item.start_date <= Date.today + 3.days

    # 检查是否已经提交很久
    return true if event_item.submitted_for_approval_at &&
                   (Time.current - event_item.submitted_for_approval_at) > 7.days

    false
  end

  # 格式化用户信息
  def user_info(user)
    return nil unless user

    {
      id: user.id,
      nickname: user.nickname,
      avatar_url: user.avatar_url
    }
  end

  def admin_user_info
    user_info(admin_user)
  end
end