class Api::V1::ReadingEventsController < Api::V1::BaseController
  before_action :authenticate_user!, except: [:index]
  before_action :set_reading_event, only: [:show, :update, :destroy, :start, :complete, :approve, :reject, :observe, :statistics, :today_task]
  before_action :authorize_event_leader!, only: [:update, :destroy, :start]
  before_action :authorize_admin!, only: [:approve, :reject]

  # GET /api/v1/reading_events
  # 活动列表和搜索
  def index
    @reading_events = ReadingEvent.includes(:leader, :event_enrollments)
                                   .filter_by_status(params[:status])
                                   .filter_by_mode(params[:activity_mode])
                                   .filter_by_fee_type(params[:fee_type])

    # 关键词搜索
    if params[:keyword].present?
      keyword = "%#{params[:keyword]}%"
      @reading_events = @reading_events.where(
        "reading_events.title ILIKE ? OR reading_events.book_name ILIKE ?",
        keyword, keyword
      )
    end

    # 时间范围过滤
    if params[:start_date_from].present?
      start_date = safe_date_param(:start_date_from)
      @reading_events = @reading_events.where('reading_events.start_date >= ?', start_date) if start_date
    end

    if params[:start_date_to].present?
      end_date = safe_date_param(:start_date_to)
      @reading_events = @reading_events.where('reading_events.start_date <= ?', end_date) if end_date
    end

    # 排序
    sorting = sorting_params(default_field: :created_at)
    @reading_events = @reading_events.order("#{sorting[:sort_field]} #{sorting[:sort_direction]}")

    # 分页
    pagination = pagination_params
    @reading_events = @reading_events.page(pagination[:page]).per(pagination[:per_page])

    # 批量获取参与者数量以避免N+1查询
    participants_counts = ReadingEvent.batch_participants_counts(@reading_events)

    # 构建响应数据
    events_data = @reading_events.map do |event|
      {
        id: event.id,
        title: event.title,
        book_name: event.book_name,
        book_cover_url: event.book_cover_url,
        description: event.description,
        activity_mode: event.activity_mode,
        fee_type: event.fee_type,
        fee_amount: event.fee_amount,
        start_date: event.start_date,
        end_date: event.end_date,
        status: event.status,
        approval_status: event.approval_status,
        participants_count: participants_counts[event.id] || 0,
        max_participants: event.max_participants,
        available_spots: event.max_participants > 0 ? (event.max_participants - (participants_counts[event.id] || 0)) : 0,
        leader: {
          id: event.leader.id,
          nickname: event.leader.nickname
        },
        created_at: event.created_at
      }
    end

    render_success(
      data: events_data,
      meta: pagination_meta(@reading_events)
    )

    log_api_call('reading_events#index')
  end

  # GET /api/v1/reading_events/:id
  # 活动详情
  def show
    event_data = {
      id: @reading_event.id,
      title: @reading_event.title,
      book_name: @reading_event.book_name,
      book_cover_url: @reading_event.book_cover_url,
      description: @reading_event.description,
      activity_mode: @reading_event.activity_mode,
      weekend_rest: @reading_event.weekend_rest,
      completion_standard: @reading_event.completion_standard,
      leader_assignment_type: @reading_event.leader_assignment_type,
      fee_type: @reading_event.fee_type,
      fee_amount: @reading_event.fee_amount,
      leader_reward_percentage: @reading_event.leader_reward_percentage,
      max_participants: @reading_event.max_participants,
      min_participants: @reading_event.min_participants,
      start_date: @reading_event.start_date,
      end_date: @reading_event.end_date,
      enrollment_deadline: @reading_event.enrollment_deadline,
      status: @reading_event.status,
      approval_status: @reading_event.approval_status,
      participants_count: @reading_event.participants_count,
      available_spots: @reading_event.available_spots,
      days_count: @reading_event.days_count,
      leader: {
        id: @reading_event.leader.id,
        nickname: @reading_event.leader.nickname
      },
      created_at: @reading_event.created_at,
      updated_at: @reading_event.updated_at
    }

    # 如果已登录，添加用户相关信息
    if current_user
      enrollment = @reading_event.event_enrollments.find_by(user: current_user)
      event_data[:user_enrollment] = enrollment ? {
        id: enrollment.id,
        enrollment_type: enrollment.enrollment_type,
        status: enrollment.status,
        enrollment_date: enrollment.enrollment_date,
        completion_rate: enrollment.completion_rate,
        check_ins_count: enrollment.check_ins_count,
        flowers_received_count: enrollment.flowers_received_count
      } : nil

      event_data[:user_permissions] = {
        can_enroll: @reading_event.can_enroll? && !enrollment,
        can_edit: current_user == @reading_event.leader,
        can_start: @reading_event.can_start? && current_user == @reading_event.leader,
        is_participant: enrollment&.can_participate? || false
      }
    end

    render_success(data: event_data)
    log_api_call('reading_events#show')
  end

  # POST /api/v1/reading_events/:id/observe
  # 围观活动
  def observe
    # 检查用户是否已经报名或围观
    existing_enrollment = @reading_event.event_enrollments.find_by(user: current_user)
    if existing_enrollment
      render_error(
        message: '您已经参与此活动',
        error_code: 'ALREADY_PARTICIPATED',
        status_code: 422
      )
      return
    end

    ActiveRecord::Base.transaction do
      # 创建围观记录
      enrollment = @reading_event.event_enrollments.build(
        user: current_user,
        enrollment_type: 'observer',
        status: 'enrolled',
        enrollment_date: Time.current
      )

      if enrollment.save
        enrollment_data = {
          id: enrollment.id,
          reading_event_id: enrollment.reading_event_id,
          enrollment_type: enrollment.enrollment_type,
          status: enrollment.status,
          enrollment_date: enrollment.enrollment_date,
          reading_event: {
            id: @reading_event.id,
            title: @reading_event.title,
            book_name: @reading_event.book_name
          }
        }

        render_success(
          data: enrollment_data,
          message: '围观成功'
        )
        log_api_call('reading_events#observe')
      else
        render_error(
          message: '围观失败',
          error_code: 'VALIDATION_ERROR',
          details: { errors: enrollment.errors.full_messages }
        )
      end
    end
  rescue => e
    render_error(
      message: '围观处理失败',
      error_code: 'OBSERVE_ERROR',
      details: { errors: [e.message] }
    )
  end

  # POST /api/v1/reading_events
  # 创建活动
  def create
    return unless authenticate_user!

    # 验证嵌套参数
    event_params = params[:reading_event] || params

    # 检查必要字段
    if event_params[:title].blank? || event_params[:book_name].blank? ||
       event_params[:start_date].blank? || event_params[:end_date].blank?
      missing_fields = []
      missing_fields << "title 不能为空" if event_params[:title].blank?
      missing_fields << "book_name 不能为空" if event_params[:book_name].blank?
      missing_fields << "start_date 不能为空" if event_params[:start_date].blank?
      missing_fields << "end_date 不能为空" if event_params[:end_date].blank?

      render_validation_error(
        missing_fields,
        message: '缺少必要参数'
      )
      return
    end

    ActiveRecord::Base.transaction do
      @reading_event = ReadingEvent.new(reading_event_params)
      @reading_event.leader = current_user
      # 简化流程：直接设为报名中，无需审批
      @reading_event.status = :enrolling
      @reading_event.approval_status = :approved

      if @reading_event.save
        event_data = build_event_data(@reading_event)
        render_success(
          data: event_data,
          message: '活动创建成功'
        )
        log_api_call('reading_events#create')
      else
        render_error(
          message: '活动创建失败',
          error_code: 'VALIDATION_ERROR',
          details: { errors: @reading_event.errors.full_messages }
        )
      end
    end
  end

  # PUT/PATCH /api/v1/reading_events/:id
  # 更新活动
  def update
    ActiveRecord::Base.transaction do
      if @reading_event.update(reading_event_params)
        event_data = build_event_data(@reading_event)
        render_success(
          data: event_data,
          message: '活动更新成功'
        )
        log_api_call('reading_events#update')
      else
        render_error(
          message: '活动更新失败',
          error_code: 'VALIDATION_ERROR',
          details: { errors: @reading_event.errors.full_messages }
        )
      end
    end
  end

  # DELETE /api/v1/reading_events/:id
  # 删除活动
  def destroy
    # 简化流程：只有尚未有人报名的活动才能删除
    if @reading_event.participants_count > 0
      render_error(
        message: '已有用户报名的活动无法删除',
        error_code: 'CANNOT_DELETE_EVENT'
      )
      return
    end

    ActiveRecord::Base.transaction do
      @reading_event.destroy!
      render_success(message: '活动删除成功')
      log_api_call('reading_events#destroy')
    end
  rescue ActiveRecord::RecordNotDestroyed
    render_error(
      message: '活动删除失败',
      error_code: 'DELETE_FAILED'
    )
  end

  # POST /api/v1/reading_events/:id/start
  # 开始活动
  def start
    unless @reading_event.can_start?
      render_error(
        message: '活动当前状态无法开始',
        error_code: 'CANNOT_START_EVENT'
      )
      return
    end

    if @reading_event.start!
      render_success(
        data: build_event_data(@reading_event),
        message: '活动已开始'
      )
      log_api_call('reading_events#start')
    else
      render_error(
        message: '活动开始失败',
        error_code: 'START_FAILED'
      )
    end
  end

  # POST /api/v1/reading_events/:id/complete
  # 完成活动（管理员或活动创建者）
  def complete
    unless @reading_event.can_complete?
      render_error(
        message: '活动当前状态无法完成',
        error_code: 'CANNOT_COMPLETE_EVENT'
      )
      return
    end

    if @reading_event.complete!
      render_success(
        data: build_event_data(@reading_event),
        message: '活动已完成'
      )
      log_api_call('reading_events#complete')
    else
      render_error(
        message: '活动完成失败',
        error_code: 'COMPLETE_FAILED'
      )
    end
  end

  # POST /api/v1/reading_events/:id/approve
  # 审批通过活动（管理员）
  def approve
    unless @reading_event.pending_approval?
      render_error(
        message: '活动当前状态无法审批',
        error_code: 'CANNOT_APPROVE_EVENT'
      )
      return
    end

    if @reading_event.approve!(current_user)
      render_success(
        data: build_event_data(@reading_event),
        message: '活动已审批通过'
      )
      log_api_call('reading_events#approve')
    else
      render_error(
        message: '活动审批失败',
        error_code: 'APPROVE_FAILED'
      )
    end
  end

  # POST /api/v1/reading_events/:id/reject
  # 拒绝活动（管理员）
  def reject
    unless @reading_event.pending_approval?
      render_error(
        message: '活动当前状态无法拒绝',
        error_code: 'CANNOT_REJECT_EVENT'
      )
      return
    end

    reason = params[:reason] || '不符合活动规范'

    if @reading_event.reject!(current_user, reason)
      render_success(
        data: build_event_data(@reading_event),
        message: '活动已拒绝'
      )
      log_api_call('reading_events#reject')
    else
      render_error(
        message: '活动拒绝失败',
        error_code: 'REJECT_FAILED'
      )
    end
  end

  # GET /api/v1/reading_events/:id/statistics
  # 活动统计信息
  def statistics
    unless @reading_event.in_progress? || @reading_event.completed?
      render_error(
        message: '活动未开始或已结束，暂无统计数据',
        error_code: 'NO_STATISTICS_AVAILABLE'
      )
      return
    end

    stats = @reading_event.completion_statistics

    # 添加参与者排行榜
    top_participants = @reading_event.event_enrollments
      .includes(:user)
      .by_completion_rate(:desc)
      .limit(10)
      .map do |enrollment|
        {
          user_id: enrollment.user.id,
          nickname: enrollment.user.nickname,
          completion_rate: enrollment.completion_rate,
          check_ins_count: enrollment.check_ins_count,
          flowers_received_count: enrollment.flowers_received_count
        }
      end

    statistics_data = {
      total_participants: stats[:total_participants],
      completed_participants: stats[:completed_participants],
      average_completion_rate: stats[:average_completion_rate],
      total_check_ins: stats[:total_check_ins],
      total_flowers: stats[:total_flowers],
      completion_rate: stats[:total_participants] > 0 ?
        (stats[:completed_participants].to_f / stats[:total_participants] * 100).round(2) : 0,
      top_participants: top_participants
    }

    render_success(data: statistics_data)
    log_api_call('reading_events#statistics')
  end

  # GET /api/v1/reading_events/:id/today_task
  # 获取今日任务
  def today_task
    # 检查用户是否已报名
    enrollment = @reading_event.event_enrollments.find_by(user: current_user)
    unless enrollment
      render_error(
        message: '您尚未报名此活动',
        error_code: 'NOT_ENROLLED',
        status: :forbidden
      )
      return
    end

    # 检查活动状态
    unless @reading_event.in_progress?
      render_error(
        message: '活动尚未开始或已结束',
        error_code: 'INVALID_ACTIVITY_STATUS',
        status: :unprocessable_entity
      )
      return
    end

    # 获取当前天数
    current_day = @reading_event.current_day

    # 查找今日的阅读计划
    today_schedule = @reading_event.reading_schedules.find_by(day_number: current_day)

    # 查找今日的领读内容
    today_leading = @reading_event.daily_leadings.joins(:reading_schedule)
                          .find_by(reading_schedules: { day_number: current_day })

    # 构建今日任务数据
    task_data = {
      day_number: current_day,
      date: Time.current.strftime('%Y年%m月%d日'),
      schedule: today_schedule ? {
        id: today_schedule.id,
        day_number: today_schedule.day_number,
        reading_content: today_schedule.reading_content,
        thinking_questions: today_schedule.thinking_questions || [],
        notes_guidance: today_schedule.notes_guidance
      } : nil,
      daily_leading: today_leading ? {
        id: today_leading.id,
        leader: {
          id: today_leading.leader.id,
          nickname: today_leading.leader.nickname,
          avatar_url: today_leading.leader.avatar_url
        },
        leading_content: today_leading.leading_content,
        discussion_questions: today_leading.discussion_questions || [],
        created_at: today_leading.created_at
      } : nil,
      activity_status: {
        can_check_in: enrollment.can_check_in?,
        has_checked_today: enrollment.has_checked_today?(current_day),
        checkin_deadline: @reading_event.checkin_deadline_for_day(current_day),
        days_until_deadline: @reading_event.days_until_checkin_deadline(current_day)
      }
    }

    render_success(data: task_data)
    log_api_call('reading_events#today_task')
  rescue => e
    render_error(
      message: '获取今日任务失败',
      error_code: 'TODAY_TASK_ERROR',
      details: { errors: [e.message] }
    )
  end

  private

  def set_reading_event
    @reading_event = ReadingEvent.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '活动不存在',
      error_code: 'EVENT_NOT_FOUND',
      status: :not_found
    )
  end

  def reading_event_params
    # 支持嵌套的 reading_event 参数
    event_params = params[:reading_event] || params

    {
      title: event_params[:title],
      book_name: event_params[:book_name],
      book_cover_url: event_params[:book_cover_url],
      description: event_params[:description],
      activity_mode: event_params[:activity_mode] || 'note_checkin',
      weekend_rest: event_params[:weekend_rest] == true,
      completion_standard: event_params[:completion_standard]&.to_i || 80,
      leader_assignment_type: event_params[:leader_assignment_type] || 'voluntary',
      fee_type: event_params[:fee_type] || 'free',
      fee_amount: event_params[:fee_amount]&.to_d || 0.0,
      leader_reward_percentage: event_params[:leader_reward_percentage]&.to_d || 20.0,
      max_participants: event_params[:max_participants]&.to_i || 25,
      min_participants: event_params[:min_participants]&.to_i || 10,
      start_date: event_params[:start_date]&.to_date,
      end_date: event_params[:end_date]&.to_date,
      enrollment_deadline: event_params[:enrollment_deadline]&.to_datetime
    }.compact
  end

  def build_event_data(event)
    {
      id: event.id,
      title: event.title,
      book_name: event.book_name,
      book_cover_url: event.book_cover_url,
      description: event.description,
      activity_mode: event.activity_mode,
      weekend_rest: event.weekend_rest,
      completion_standard: event.completion_standard,
      leader_assignment_type: event.leader_assignment_type,
      fee_type: event.fee_type,
      fee_amount: event.fee_amount,
      leader_reward_percentage: event.leader_reward_percentage,
      max_participants: event.max_participants,
      min_participants: event.min_participants,
      start_date: event.start_date,
      end_date: event.end_date,
      enrollment_deadline: event.enrollment_deadline,
      status: event.status,
      approval_status: event.approval_status,
      participants_count: event.participants_count,
      available_spots: event.available_spots,
      days_count: event.days_count,
      leader: {
        id: event.leader.id,
        nickname: event.leader.nickname
      },
      created_at: event.created_at,
      updated_at: event.updated_at
    }
  end
end
