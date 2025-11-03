class Api::V1::ApprovalWorkflowController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :check_admin_permissions

  # POST /api/v1/approval_workflow/submit_for_approval
  # 提交活动审批
  def submit_for_approval
    event_id = params[:event_id]
    workflow_type = params[:workflow_type]&.to_sym || :standard

    unless event_id.present?
      render_error(
        message: '请提供活动ID',
        code: 'EVENT_ID_REQUIRED',
        status: :unprocessable_entity
      )
      return
    end

    event = ReadingEvent.find_by(id: event_id)
    unless event
      render_error(
        message: '活动不存在',
        code: 'EVENT_NOT_FOUND',
        status: :not_found
      )
      return
    end

    # 检查权限（只有活动创建者可以提交审批）
    unless event.leader == current_user
      render_error(
        message: '只有活动创建者可以提交审批',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    service = ActivityApprovalWorkflowService.submit_for_approval!(event, workflow_type: workflow_type)

    if service.success?
      render_success(
        data: service.result,
        message: service.result[:message]
      )
      log_api_call('approval_workflow#submit_for_approval')
    else
      render_error(
        message: service.error_message,
        code: 'SUBMIT_FOR_APPROVAL_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '活动不存在',
      code: 'EVENT_NOT_FOUND',
      status: :not_found
    )
  rescue => e
    render_error(
      message: '提交审批失败',
      errors: [e.message],
      code: 'SUBMIT_FOR_APPROVAL_ERROR'
    )
  end

  # POST /api/v1/approval_workflow/approve_event
  # 审批通过活动
  def approve_event
    event_id = params[:event_id]
    reason = params[:reason]
    notes = params[:notes]

    unless event_id.present?
      render_error(
        message: '请提供活动ID',
        code: 'EVENT_ID_REQUIRED',
        status: :unprocessable_entity
      )
      return
    end

    event = ReadingEvent.find_by(id: event_id)
    unless event
      render_error(
        message: '活动不存在',
        code: 'EVENT_NOT_FOUND',
        status: :not_found
      )
      return
    end

    service = ActivityApprovalWorkflowService.approve!(event, current_user, reason: reason, notes: notes)

    if service.success?
      render_success(
        data: service.result,
        message: service.result[:message]
      )
      log_api_call('approval_workflow#approve_event')
    else
      render_error(
        message: service.error_message,
        code: 'APPROVE_EVENT_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '活动不存在',
      code: 'EVENT_NOT_FOUND',
      status: :not_found
    )
  rescue => e
    render_error(
      message: '审批通过失败',
      errors: [e.message],
      code: 'APPROVE_EVENT_ERROR'
    )
  end

  # POST /api/v1/approval_workflow/reject_event
  # 审批拒绝活动
  def reject_event
    event_id = params[:event_id]
    reason = params[:reason]
    notes = params[:notes]

    unless event_id.present?
      render_error(
        message: '请提供活动ID',
        code: 'EVENT_ID_REQUIRED',
        status: :unprocessable_entity
      )
      return
    end

    unless reason.present?
      render_error(
        message: '请提供拒绝理由',
        code: 'REJECTION_REASON_REQUIRED',
        status: :unprocessable_entity
      )
      return
    end

    event = ReadingEvent.find_by(id: event_id)
    unless event
      render_error(
        message: '活动不存在',
        code: 'EVENT_NOT_FOUND',
        status: :not_found
      )
      return
    end

    service = ActivityApprovalWorkflowService.reject!(event, current_user, reason, notes: notes)

    if service.success?
      render_success(
        data: service.result,
        message: service.result[:message]
      )
      log_api_call('approval_workflow#reject_event')
    else
      render_error(
        message: service.error_message,
        code: 'REJECT_EVENT_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '活动不存在',
      code: 'EVENT_NOT_FOUND',
      status: :not_found
    )
  rescue => e
    render_error(
      message: '审批拒绝失败',
      errors: [e.message],
      code: 'REJECT_EVENT_ERROR'
    )
  end

  # POST /api/v1/approval_workflow/batch_approve
  # 批量审批通过
  def batch_approve
    event_ids = params[:event_ids]
    reason = params[:reason]

    unless event_ids.present? && event_ids.is_a?(Array)
      render_error(
        message: '请提供有效的活动ID列表',
        code: 'EVENT_IDS_REQUIRED',
        status: :unprocessable_entity
      )
      return
    end

    service = ActivityApprovalWorkflowService.batch_approve!(event_ids, current_user, reason: reason)

    if service.success?
      render_success(
        data: service.result,
        message: service.result[:message]
      )
      log_api_call('approval_workflow#batch_approve')
    else
      render_error(
        message: service.error_message,
        code: 'BATCH_APPROVE_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue => e
    render_error(
      message: '批量审批失败',
      errors: [e.message],
      code: 'BATCH_APPROVE_ERROR'
    )
  end

  # POST /api/v1/approval_workflow/batch_reject
  # 批量审批拒绝
  def batch_reject
    event_ids = params[:event_ids]
    reason = params[:reason]
    notes = params[:notes]

    unless event_ids.present? && event_ids.is_a?(Array)
      render_error(
        message: '请提供有效的活动ID列表',
        code: 'EVENT_IDS_REQUIRED',
        status: :unprocessable_entity
      )
      return
    end

    unless reason.present?
      render_error(
        message: '请提供拒绝理由',
        code: 'REJECTION_REASON_REQUIRED',
        status: :unprocessable_entity
      )
      return
    end

    service = ActivityApprovalWorkflowService.batch_reject!(event_ids, current_user, reason, notes: notes)

    if service.success?
      render_success(
        data: service.result,
        message: service.result[:message]
      )
      log_api_call('approval_workflow#batch_reject')
    else
      render_error(
        message: service.error_message,
        code: 'BATCH_REJECT_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue => e
    render_error(
      message: '批量拒绝失败',
      errors: [e.message],
      code: 'BATCH_REJECT_ERROR'
    )
  end

  # GET /api/v1/approval_workflow/approval_queue
  # 获取审批队列
  def approval_queue
    filters = {
      page: safe_integer_param(params[:page]) || 1,
      per_page: safe_integer_param(params[:per_page]) || 20,
      leader_id: safe_integer_param(params[:leader_id]),
      activity_mode: params[:activity_mode],
      fee_type: params[:fee_type],
      submitted_since: parse_date_param(params[:submitted_since]),
      submitted_until: parse_date_param(params[:submitted_until])
    }.compact

    service = ActivityApprovalWorkflowService.approval_queue(current_user, filters: filters)

    if service.success?
      render_success(
        data: service.result
      )
      log_api_call('approval_workflow#approval_queue')
    else
      render_error(
        message: service.error_message,
        code: 'GET_APPROVAL_QUEUE_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue => e
    render_error(
      message: '获取审批队列失败',
      errors: [e.message],
      code: 'GET_APPROVAL_QUEUE_ERROR'
    )
  end

  # GET /api/v1/approval_workflow/approval_statistics
  # 获取审批统计
  def approval_statistics
    date_range = nil
    if params[:start_date].present? && params[:end_date].present?
      start_date = parse_date_param(params[:start_date])
      end_date = parse_date_param(params[:end_date])
      date_range = (start_date..end_date) if start_date && end_date
    end

    service = ActivityApprovalWorkflowService.approval_statistics(current_user, date_range: date_range)

    if service.success?
      render_success(
        data: service.result
      )
      log_api_call('approval_workflow#approval_statistics')
    else
      render_error(
        message: service.error_message,
        code: 'GET_APPROVAL_STATISTICS_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue => e
    render_error(
      message: '获取审批统计失败',
      errors: [e.message],
      code: 'GET_APPROVAL_STATISTICS_ERROR'
    )
  end

  # POST /api/v1/approval_workflow/escalate_approval
  # 升级审批
  def escalate_approval
    event_id = params[:event_id]
    escalation_reason = params[:escalation_reason]

    unless event_id.present?
      render_error(
        message: '请提供活动ID',
        code: 'EVENT_ID_REQUIRED',
        status: :unprocessable_entity
      )
      return
    end

    unless escalation_reason.present?
      render_error(
        message: '请提供升级理由',
        code: 'ESCALATION_REASON_REQUIRED',
        status: :unprocessable_entity
      )
      return
    end

    event = ReadingEvent.find_by(id: event_id)
    unless event
      render_error(
        message: '活动不存在',
        code: 'EVENT_NOT_FOUND',
        status: :not_found
      )
      return
    end

    service = ActivityApprovalWorkflowService.escalate!(event, current_user, escalation_reason)

    if service.success?
      render_success(
        data: service.result,
        message: service.result[:message]
      )
      log_api_call('approval_workflow#escalate_approval')
    else
      render_error(
        message: service.error_message,
        code: 'ESCALATE_APPROVAL_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '活动不存在',
      code: 'EVENT_NOT_FOUND',
      status: :not_found
    )
  rescue => e
    render_error(
      message: '升级审批失败',
      errors: [e.message],
      code: 'ESCALATE_APPROVAL_ERROR'
    )
  end

  # GET /api/v1/approval_workflow/event_approval_status
  # 获取活动审批状态
  def event_approval_status
    event_id = params[:event_id]

    unless event_id.present?
      render_error(
        message: '请提供活动ID',
        code: 'EVENT_ID_REQUIRED',
        status: :unprocessable_entity
      )
      return
    end

    event = ReadingEvent.find_by(id: event_id)
    unless event
      render_error(
        message: '活动不存在',
        code: 'EVENT_NOT_FOUND',
        status: :not_found
      )
      return
    end

    # 检查查看权限
    unless can_view_event_approval_status?(event)
      render_error(
        message: '权限不足，无法查看审批状态',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    approval_status_data = {
      event_id: event.id,
      title: event.title,
      status: event.status,
      approval_status: event.approval_status,
      submitted_for_approval_at: event.submitted_for_approval_at,
      approved_at: event.approved_at,
      approver: event.approver ? user_info(event.approver) : nil,
      approval_reason: event.approval_reason,
      approval_notes: event.approval_notes,
      rejection_reason: event.rejection_reason,
      escalated_at: event.escalated_at,
      escalated_by: event.escalated_by ? user_info(event.escalated_by) : nil,
      escalation_reason: event.escalation_reason,
      can_submit_for_approval: event.can_submit_for_approval?,
      can_resubmit_for_approval: event.can_resubmit_for_approval?,
      approval_queue_position: get_approval_queue_position(event),
      validation_status: validate_event_for_approval_display(event)
    }

    render_success(
      data: approval_status_data
    )
    log_api_call('approval_workflow#event_approval_status')
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '活动不存在',
      code: 'EVENT_NOT_FOUND',
      status: :not_found
    )
  rescue => e
    render_error(
      message: '获取审批状态失败',
      errors: [e.message],
      code: 'GET_APPROVAL_STATUS_ERROR'
    )
  end

  private

  # 检查管理员权限
  def check_admin_permissions
    unless current_user.can_approve_events? || current_user.can_view_approval_queue?
      render_error(
        message: '权限不足',
        code: 'FORBIDDEN',
        status: :forbidden
      )
    end
  end

  # 检查是否可以查看活动审批状态
  def can_view_event_approval_status?(event)
    # 活动创建者可以查看
    return true if event.leader == current_user

    # 管理员可以查看
    return true if current_user.can_approve_events?

    false
  end

  # 获取审批队列位置
  def get_approval_queue_position(event)
    return nil unless event.pending_approval?

    ReadingEvent.where(approval_status: :pending)
      .where('submitted_for_approval_at <= ?', event.submitted_for_approval_at)
      .count
  end

  # 验证活动审批状态显示
  def validate_event_for_approval_display(event)
    validation_result = event.send(:validate_event_for_approval)
    {
      valid: validation_result[:valid],
      errors: validation_result[:errors],
      missing_fields: get_missing_required_fields(event)
    }
  end

  # 获取缺失的必填字段
  def get_missing_required_fields(event)
    missing_fields = []

    required_fields = [
      { field: :title, name: '活动标题' },
      { field: :book_name, name: '书籍名称' },
      { field: :description, name: '活动描述' },
      { field: :start_date, name: '开始日期' },
      { field: :end_date, name: '结束日期' },
      { field: :max_participants, name: '最大参与人数' }
    ]

    required_fields.each do |field_config|
      value = event.send(field_config[:field])
      if value.blank?
        missing_fields << {
          field: field_config[:field],
          name: field_config[:name],
          current_value: value
        }
      end
    end

    # 检查费用相关字段（如果是收费活动）
    if event.fee_type != 'free'
      fee_fields = [
        { field: :fee_amount, name: '费用金额' },
        { field: :leader_reward_percentage, name: '领读人奖励比例' }
      ]

      fee_fields.each do |field_config|
        value = event.send(field_config[:field])
        if value.blank? || value.to_f <= 0
          missing_fields << {
            field: field_config[:field],
            name: field_config[:name],
            current_value: value
          }
        end
      end
    end

    missing_fields
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

  # 安全整数参数转换
  def safe_integer_param(param)
    return nil if param.blank?

    Integer(param)
  rescue ArgumentError, TypeError
    nil
  end

  # 解析日期参数
  def parse_date_param(param)
    return nil if param.blank?

    Date.parse(param.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end