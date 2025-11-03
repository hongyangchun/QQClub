class Api::V1::EventEnrollmentsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_reading_event
  before_action :set_enrollment, only: [:show, :cancel, :update]

  # POST /api/v1/event_enrollments
  # 报名参加活动
  def create
    # 从嵌套参数中获取reading_event_id
    if params[:event_enrollment]&.dig(:reading_event_id).blank?
      render_validation_error(['reading_event_id 不能为空'])
      return
    end

    ActiveRecord::Base.transaction do
      # 检查活动是否可以报名
      unless @reading_event.can_enroll?
        render_error(
          message: @reading_event.enrollment_error_message || '活动当前无法报名',
          error_code: 'CANNOT_ENROLL',
          status_code: 422
        )
        return
      end

      # 检查用户是否已经报名
      existing_enrollment = @reading_event.event_enrollments.find_by(user: current_user)
      if existing_enrollment
        render_error(
          message: '您已经报名过此活动',
          error_code: 'ALREADY_ENROLLED',
          status_code: 422
        )
        return
      end

      # 创建报名记录
      enrollment = @reading_event.event_enrollments.build(
        user: current_user,
        enrollment_type: params[:enrollment_type]&.to_s || 'participant',
        status: 'enrolled',
        enrollment_date: Time.current
      )

      # 处理费用（如果有）
      if @reading_event.fee_type != 'free'
        fee_amount = @reading_event.fee_amount
        enrollment.fee_paid_amount = fee_amount

        # 这里应该调用支付服务
        # payment_result = PaymentService.process(current_user, fee_amount, @reading_event)
        # unless payment_result.success?
        #   render_error(message: '支付失败', code: 'PAYMENT_FAILED', status: :unprocessable_entity)
        #   return
        # end
      end

      if enrollment.save
        # 发送报名确认通知（暂时注释掉，因为服务未实现）
        # enrollment.notify_enrollment_confirmation

        enrollment_data = build_enrollment_data(enrollment)
        render_success(
          data: enrollment_data,
          message: '报名成功'
        )
        log_api_call('event_enrollments#create')
      else
        render_error(
          message: '报名失败',
          error_code: 'VALIDATION_ERROR',
          details: { errors: enrollment.errors.full_messages }
        )
      end
    end
  rescue => e
    render_error(
      message: '报名处理失败',
      error_code: 'ENROLLMENT_ERROR',
      details: { errors: [e.message] }
    )
  end

  # GET /api/v1/event_enrollments/:id
  # 获取报名详情
  def show
    unless @enrollment
      render_error(
        message: '报名记录不存在',
        error_code: 'ENROLLMENT_NOT_FOUND',
        status_code: 404
      )
      return
    end

    # 检查权限：只有报名者本人或活动创建者可以查看
    unless @enrollment.user == current_user || @reading_event.leader == current_user
      render_error(
        message: '权限不足',
        error_code: 'FORBIDDEN',
        status_code: 403
      )
      return
    end

    enrollment_data = build_enrollment_data(@enrollment, detailed: true)
    render_success(data: enrollment_data)
    log_api_call('event_enrollments#show')
  end

  # POST /api/v1/event_enrollments/:id/cancel
  # 取消报名
  def cancel
    unless @enrollment
      render_error(
        message: '报名记录不存在',
        error_code: 'ENROLLMENT_NOT_FOUND',
        status_code: 404
      )
      return
    end

    # 检查权限：只有报名者本人可以取消
    unless @enrollment.user == current_user
      render_error(
        message: '权限不足',
        error_code: 'FORBIDDEN',
        status_code: 403
      )
      return
    end

    # 检查是否可以取消
    unless @enrollment.can_cancel?
      render_error(
        message: @enrollment.cancellation_error_message || '当前状态无法取消报名',
        error_code: 'CANNOT_CANCEL',
        status_code: 422
      )
      return
    end

    ActiveRecord::Base.transaction do
      # 处理退款（如果有）
      if @enrollment.fee_paid_amount > 0
        @enrollment.process_refund!
      end

      # 更新状态
      @enrollment.update!(status: 'cancelled')

      # 发送取消通知
      # EnrollmentNotificationService.notify_cancellation(@enrollment)

      render_success(
        data: build_enrollment_data(@enrollment),
        message: '报名已取消'
      )
      log_api_call('event_enrollments#cancel')
    end
  rescue => e
    render_error(
      message: '取消报名失败',
      error_code: 'CANCELLATION_ERROR',
      details: { errors: [e.message] }
    )
  end

  # PUT/PATCH /api/v1/event_enrollments/:id
  # 更新报名信息（仅限特定字段）
  def update
    unless @enrollment
      render_error(
        message: '报名记录不存在',
        error_code: 'ENROLLMENT_NOT_FOUND',
        status_code: 404
      )
      return
    end

    # 检查权限：只有报名者本人可以更新
    unless @enrollment.user == current_user
      render_error(
        message: '权限不足',
        error_code: 'FORBIDDEN',
        status_code: 403
      )
      return
    end

    # 只允许更新特定字段
    allowed_fields = [:enrollment_type]
    update_params = params.slice(*allowed_fields).compact

    if update_params.empty?
      render_error(
        message: '没有可更新的字段',
        error_code: 'NO_UPDATABLE_FIELDS'
      )
      return
    end

    ActiveRecord::Base.transaction do
      if @enrollment.update(update_params)
        render_success(
          data: build_enrollment_data(@enrollment),
          message: '报名信息更新成功'
        )
        log_api_call('event_enrollments#update')
      else
        render_error(
          message: '更新失败',
          error_code: 'VALIDATION_ERROR',
          details: { errors: @enrollment.errors.full_messages }
        )
      end
    end
  rescue => e
    render_error(
      message: '更新失败',
      error_code: 'UPDATE_ERROR',
      details: { errors: [e.message] }
    )
  end

  # GET /api/v1/reading_events/:reading_event_id/enrollments
  # 获取活动的报名列表（活动创建者可用）
  def index
    # 检查权限：只有活动创建者可以查看报名列表
    unless @reading_event.leader == current_user
      render_error(
        message: '权限不足',
        error_code: 'FORBIDDEN',
        status_code: 403
      )
      return
    end

    # 获取报名列表
    enrollments = @reading_event.event_enrollments
                           .includes(:user)
                           .order(enrollment_date: :desc)

    # 分页
    pagination = pagination_params
    enrollments = enrollments.page(pagination[:page]).per(pagination[:per_page])

    # 构建响应数据
    enrollments_data = enrollments.map do |enrollment|
      build_enrollment_data(enrollment, detailed: true)
    end

    render_success(
      data: enrollments_data,
      meta: pagination_meta(enrollments)
    )
    log_api_call('event_enrollments#index')
  end

  # GET /api/v1/reading_events/:reading_event_id/enrollments/statistics
  # 获取活动报名统计（活动创建者可用）
  def statistics
    # 检查权限：只有活动创建者可以查看统计
    unless @reading_event.leader == current_user
      render_error(
        message: '权限不足',
        error_code: 'FORBIDDEN',
        status_code: 403
      )
      return
    end

    # 计算统计数据
    stats = @reading_event.event_enrollments.calculate_enrollment_statistics

    render_success(data: stats)
    log_api_call('event_enrollments#statistics')
  end

  # GET /api/v1/event_enrollments/my_progress
  # 获取我的活动进度
  def my_progress
    return unless validate_required_fields(:reading_event_id)

    # 查找用户在该活动中的报名记录
    enrollment = EventEnrollment.joins(:reading_event)
                     .find_by(user: current_user, reading_event_id: params[:reading_event_id])

    unless enrollment
      render_error(
        message: '您尚未报名此活动',
        error_code: 'NOT_ENROLLED',
        status_code: 404
      )
      return
    end

    progress_data = {
      enrollment_id: enrollment.id,
      reading_event_id: enrollment.reading_event_id,
      enrollment_type: enrollment.enrollment_type,
      status: enrollment.status,
      completion_rate: enrollment.completion_rate || 0,
      check_ins_count: enrollment.check_ins_count || 0,
      leader_days_count: enrollment.leader_days_count || 0,
      flowers_received_count: enrollment.flowers_received_count || 0,
      enrollment_date: enrollment.enrollment_date,
      last_checkin_date: enrollment.last_checkin_date,
      can_check_in: enrollment.can_check_in?,
      is_completed: enrollment.is_completed?,
      progress_percentage: calculate_progress_percentage(enrollment)
    }

    render_success(data: progress_data)
    log_api_call('event_enrollments#my_progress')
  rescue => e
    render_error(
      message: '获取进度失败',
      error_code: 'PROGRESS_ERROR',
      details: { errors: [e.message] }
    )
  end

  private

  def set_reading_event
    event_id = params[:reading_event_id] || params[:id] ||
               (params[:event_enrollment] && params[:event_enrollment][:reading_event_id])
    @reading_event = ReadingEvent.find(event_id)
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '活动不存在',
      error_code: 'EVENT_NOT_FOUND',
      status_code: 404
    )
  end

  def set_enrollment
    @enrollment = @reading_event.event_enrollments.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    @enrollment = nil
  end

  def build_enrollment_data(enrollment, detailed: false)
    data = {
      id: enrollment.id,
      enrollment_type: enrollment.enrollment_type,
      status: enrollment.status,
      enrollment_date: enrollment.enrollment_date,
      completion_rate: enrollment.completion_rate,
      check_ins_count: enrollment.check_ins_count,
      leader_days_count: enrollment.leader_days_count,
      flowers_received_count: enrollment.flowers_received_count,
      fee_paid_amount: enrollment.fee_paid_amount,
      fee_refund_amount: enrollment.fee_refund_amount,
      refund_status: enrollment.refund_status,
      created_at: enrollment.created_at,
      updated_at: enrollment.updated_at
    }

    if detailed
      data[:user] = {
        id: enrollment.user.id,
        nickname: enrollment.user.nickname,
        avatar_url: enrollment.user.avatar_url
      }

      data[:reading_event] = {
        id: enrollment.reading_event.id,
        title: enrollment.reading_event.title,
        book_name: enrollment.reading_event.book_name
      }

      data[:permissions] = {
        can_cancel: enrollment.can_cancel?,
        can_update: enrollment.user == current_user,
        can_check_in: enrollment.can_check_in?,
        can_receive_flowers: enrollment.can_receive_flowers?,
        can_give_flowers: enrollment.can_give_flowers?
      }

      data[:status_info] = {
        can_participate: enrollment.can_participate?,
        is_completed: enrollment.is_completed?,
        eligible_for_completion_certificate: enrollment.eligible_for_completion_certificate?,
        eligible_for_flower_certificate: enrollment.eligible_for_flower_certificate?
      }
    end

    data
  end

  # 计算进度百分比
  def calculate_progress_percentage(enrollment)
    return 0 unless enrollment.reading_event&.days_count && enrollment.reading_event.days_count > 0

    if enrollment.completion_rate.present?
      return enrollment.completion_rate
    end

    # 如果没有明确的完成率，根据打卡天数估算
    check_ins_count = enrollment.check_ins_count || 0
    days_count = enrollment.reading_event.days_count

    return [(check_ins_count.to_f / days_count * 100).round, 100].min
  end
end