class Api::V1::ReadingSchedulesController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_reading_event
  before_action :set_reading_schedule, only: [:show, :assign_leader, :remove_leader]

  # GET /api/v1/reading_schedules
  # 阅读计划列表
  def index
    # 检查权限：只有活动参与者、创建者可以查看
    unless can_view_schedules?
      render_error(
        message: '权限不足',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    # 获取阅读计划列表
    schedules = @reading_event.reading_schedules
                           .includes(:daily_leader, :daily_leading, :check_ins, :flowers)
                           .chronological

    # 分页
    pagination = pagination_params
    schedules = schedules.page(pagination[:page]).per(pagination[:per_page])

    # 构建响应数据
    schedules_data = schedules.map do |schedule|
      build_schedule_data(schedule, detailed: true)
    end

    render_success(
      data: schedules_data,
      meta: pagination_meta(schedules)
    )

    log_api_call('reading_schedules#index')
  end

  # GET /api/v1/reading_schedules/:id
  # 阅读计划详情
  def show
    unless @reading_schedule
      render_error(
        message: '阅读计划不存在',
        code: 'SCHEDULE_NOT_FOUND',
        status: :not_found
      )
      return
    end

    # 检查权限
    unless can_view_schedule?(@reading_schedule)
      render_error(
        message: '权限不足',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    schedule_data = build_schedule_data(@reading_schedule, detailed: true)
    render_success(data: schedule_data)
    log_api_call('reading_schedules#show')
  end

  # POST /api/v1/reading_schedules/:id/assign_leader
  # 分配领读人
  def assign_leader
    unless @reading_schedule
      render_error(
        message: '阅读计划不存在',
        code: 'SCHEDULE_NOT_FOUND',
        status: :not_found
      )
      return
    end

    # 检查权限：只有活动创建者可以分配领读人
    unless @reading_event.leader == current_user
      render_error(
        message: '只有活动创建者可以分配领读人',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    # 检查用户参数
    return unless validate_required_fields(:user_id)

    target_user = User.find(params[:user_id])
    unless target_user
      render_error(
        message: '用户不存在',
        code: 'USER_NOT_FOUND',
        status: :not_found
      )
      return
    end

    # 检查用户是否是活动参与者
    unless @reading_event.participants.include?(target_user)
      render_error(
        message: '只能分配活动的参与者作为领读人',
        code: 'USER_NOT_PARTICIPANT',
        status: :unprocessable_entity
      )
      return
    end

    ActiveRecord::Base.transaction do
      if @reading_schedule.assign_leader!(target_user)
        schedule_data = build_schedule_data(@reading_schedule, detailed: true)
        render_success(
          data: schedule_data,
          message: '领读人分配成功'
        )
        log_api_call('reading_schedules#assign_leader')
      else
        render_error(
          message: '领读人分配失败',
          code: 'ASSIGN_LEADER_FAILED'
        )
      end
    end
  rescue => e
    render_error(
      message: '领读人分配失败',
      errors: [e.message],
      code: 'ASSIGN_LEADER_ERROR'
    )
  end

  # POST /api/v1/reading_schedules/:id/remove_leader
  # 移除领读人
  def remove_leader
    unless @reading_schedule
      render_error(
        message: '阅读计划不存在',
        code: 'SCHEDULE_NOT_FOUND',
        status: :not_found
      )
      return
    end

    # 检查权限：只有活动创建者可以移除领读人
    unless @reading_event.leader == current_user
      render_error(
        message: '只有活动创建者可以移除领读人',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    ActiveRecord::Base.transaction do
      if @reading_schedule.remove_leader!
        schedule_data = build_schedule_data(@reading_schedule, detailed: true)
        render_success(
          data: schedule_data,
          message: '领读人移除成功'
        )
        log_api_call('reading_schedules#remove_leader')
      else
        render_error(
          message: '领读人移除失败',
          code: 'REMOVE_LEADER_FAILED'
        )
      end
    end
  rescue => e
    render_error(
      message: '领读人移除失败',
      errors: [e.message],
      code: 'REMOVE_LEADER_ERROR'
    )
  end

  private

  def set_reading_event
    event_id = params[:reading_event_id]
    @reading_event = ReadingEvent.find(event_id)
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '活动不存在',
      code: 'EVENT_NOT_FOUND',
      status: :not_found
    )
  end

  def set_reading_schedule
    @reading_schedule = @reading_event.reading_schedules.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    @reading_schedule = nil
  end

  def build_schedule_data(schedule, detailed: false)
    data = {
      id: schedule.id,
      day_number: schedule.day_number,
      date: schedule.date,
      reading_progress: schedule.reading_progress,
      daily_leader: schedule.daily_leader ? {
        id: schedule.daily_leader.id,
        nickname: schedule.daily_leader.nickname,
        avatar_url: schedule.daily_leader.avatar_url
      } : nil,
      created_at: schedule.created_at,
      updated_at: schedule.updated_at
    }

    if detailed
      data[:reading_event] = {
        id: schedule.reading_event.id,
        title: schedule.reading_event.title,
        book_name: schedule.reading_event.book_name,
        status: schedule.reading_event.status,
        activity_mode: schedule.reading_event.activity_mode
      }

      data[:daily_leading] = schedule.daily_leading ? {
        id: schedule.daily_leading.id,
        content: schedule.daily_leading.content,
        reading_pages: schedule.daily_leading.reading_pages,
        created_at: schedule.daily_leading.created_at,
        updated_at: schedule.daily_leading.updated_at
      } : nil

      data[:statistics] = schedule.participation_statistics
      data[:status_info] = {
        today?: schedule.today?,
        past?: schedule.past?,
        future?: schedule.future?,
        current_day?: schedule.current_day?,
        completed?: schedule.completed?,
        has_check_ins?: schedule.has_check_ins?,
        has_flowers?: schedule.has_flowers?,
        has_leading_content?: schedule.has_leading_content?
      }

      data[:permissions] = {
        can_view: can_view_schedule?(schedule),
        can_assign_leader: can_assign_leader?(schedule),
        can_remove_leader: can_remove_leader?(schedule),
        can_publish_content: schedule.can_publish_leading_content?,
        can_give_flowers: schedule.can_give_flowers?,
        needs_backup: schedule.needs_backup?,
        backup_permissions: schedule.backup_permissions
      }

      data[:leading_status] = {
        content: schedule.leading_content_status,
        flowers: schedule.flower_giving_status
      }
    end

    data
  end

  # 权限检查方法
  def can_view_schedules?
    return true if @reading_event.leader == current_user
    return true if @reading_event.participants.include?(current_user)
    false
  end

  def can_view_schedule?(schedule)
    return true if @reading_event.leader == current_user
    return true if schedule.daily_leader == current_user
    return true if @reading_event.participants.include?(current_user)
    false
  end

  def can_assign_leader?(schedule)
    return false unless @reading_event.leader == current_user
    schedule.can_assign_leader?
  end

  def can_remove_leader?(schedule)
    return false unless @reading_event.leader == current_user
    schedule.daily_leader.present?
  end
end