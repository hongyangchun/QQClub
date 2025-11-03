class Api::V1::DailyLeadingsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_reading_event
  before_action :set_reading_schedule
  before_action :set_daily_leading, only: [:show, :update, :destroy]

  # POST /api/v1/reading_schedules/:reading_schedule_id/daily_leading
  # 创建领读内容
  def create
    # 检查权限：领读人（权限窗口内）或活动创建者
    unless can_create_daily_leading?
      render_error(
        message: '权限不足，只能在指定时间窗口内发布领读内容',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    return unless validate_required_fields(:content)

    ActiveRecord::Base.transaction do
      daily_leading = @reading_schedule.build_daily_leading(
        reading_suggestion: params[:reading_suggestion] || params[:content],
        questions: params[:questions] || "暂无问题",
        leader: current_user
      )

      if daily_leading.save
        # 通知领读内容已发布 (暂时注释掉，因为服务尚未实现)
        # @reading_schedule.notify_leading_content_published

        leading_data = build_daily_leading_data(daily_leading)
        render_success(
          data: leading_data,
          message: '领读内容发布成功'
        )
        log_api_call('daily_leadings#create')
      else
        render_error(
          message: '领读内容发布失败',
          errors: daily_leading.errors.full_messages,
          code: 'VALIDATION_ERROR'
        )
      end
    end
  rescue => e
    render_error(
      message: '领读内容发布失败',
      errors: [e.message],
      code: 'DAILY_LEADING_ERROR'
    )
  end

  # GET /api/v1/reading_schedules/:reading_schedule_id/daily_leading
  # 获取领读内容
  def show
    unless can_view_daily_leading?
      render_error(
        message: '权限不足',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    if @daily_leading
      leading_data = build_daily_leading_data(@daily_leading, detailed: true)
      render_success(data: leading_data)
    else
      render_success(
        data: nil,
        message: '暂无领读内容'
      )
    end

    log_api_call('daily_leadings#show')
  end

  # PUT/PATCH /api/v1/reading_schedules/:reading_schedule_id/daily_leading
  # 更新领读内容
  def update
    unless @daily_leading
      render_error(
        message: '领读内容不存在',
        code: 'DAILY_LEADING_NOT_FOUND',
        status: :not_found
      )
      return
    end

    # 检查权限：领读人（权限窗口内）或活动创建者
    unless can_update_daily_leading?
      render_error(
        message: '权限不足，只能在指定时间窗口内更新领读内容',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    update_params = {}
    if params[:content].present? || params[:reading_suggestion].present?
      update_params[:reading_suggestion] = params[:reading_suggestion] || params[:content]
    end
    if params[:questions].present?
      update_params[:questions] = params[:questions]
    end

    if update_params.empty?
      render_error(
        message: '没有可更新的字段',
        code: 'NO_UPDATABLE_FIELDS'
      )
      return
    end

    ActiveRecord::Base.transaction do
      if @daily_leading.update(update_params)
        leading_data = build_daily_leading_data(@daily_leading, detailed: true)
        render_success(
          data: leading_data,
          message: '领读内容更新成功'
        )
        log_api_call('daily_leadings#update')
      else
        render_error(
          message: '领读内容更新失败',
          errors: @daily_leading.errors.full_messages,
          code: 'VALIDATION_ERROR'
        )
      end
    end
  rescue => e
    render_error(
      message: '领读内容更新失败',
      errors: [e.message],
      code: 'DAILY_LEADING_UPDATE_ERROR'
    )
  end

  # DELETE /api/v1/reading_schedules/:reading_schedule_id/daily_leading
  # 删除领读内容
  def destroy
    unless @daily_leading
      render_error(
        message: '领读内容不存在',
        code: 'DAILY_LEADING_NOT_FOUND',
        status: :not_found
      )
      return
    end

    # 检查权限：只有活动创建者可以删除领读内容
    unless @reading_event.leader == current_user
      render_error(
        message: '只有活动创建者可以删除领读内容',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    ActiveRecord::Base.transaction do
      @daily_leading.destroy!
      render_success(message: '领读内容删除成功')
      log_api_call('daily_leadings#destroy')
    end
  rescue ActiveRecord::RecordNotDestroyed
    render_error(
      message: '领读内容删除失败',
      code: 'DELETE_FAILED'
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
    schedule_id = params[:reading_schedule_id]
    @reading_schedule = @reading_event.reading_schedules.find(schedule_id)
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '阅读计划不存在',
      code: 'SCHEDULE_NOT_FOUND',
      status: :not_found
    )
  end

  def set_daily_leading
    @daily_leading = @reading_schedule.daily_leading
  rescue ActiveRecord::RecordNotFound
    @daily_leading = nil
  end

  def build_daily_leading_data(daily_leading, detailed: false)
    data = {
      id: daily_leading.id,
      reading_suggestion: daily_leading.reading_suggestion,
      questions: daily_leading.questions,
      created_at: daily_leading.created_at,
      updated_at: daily_leading.updated_at
    }

    if detailed
      data[:reading_schedule] = {
        id: daily_leading.reading_schedule.id,
        day_number: daily_leading.reading_schedule.day_number,
        date: daily_leading.reading_schedule.date
      }

      data[:reading_event] = {
        id: daily_leading.reading_schedule.reading_event.id,
        title: daily_leading.reading_schedule.reading_event.title,
        book_name: daily_leading.reading_schedule.reading_event.book_name
      }

      data[:leader] = daily_leading.leader ? {
        id: daily_leading.leader.id,
        nickname: daily_leading.leader.nickname
      } : nil

      data[:permissions] = {
        can_view: can_view_daily_leading?,
        can_update: can_update_daily_leading?,
        can_delete: can_delete_daily_leading?
      }
    end

    data
  end

  # 权限检查方法
  def can_create_daily_leading?
    # 活动创建者始终可以创建
    return true if @reading_event.leader == current_user

    # 领读人在权限窗口内可以创建
    return true if @reading_schedule.daily_leader == current_user &&
                    @reading_schedule.can_publish_leading_content?

    false
  end

  def can_view_daily_leading?
    # 活动创建者、领读人、参与者都可以查看
    return true if @reading_event.leader == current_user
    return true if @reading_schedule.daily_leader == current_user
    return true if @reading_event.participants.include?(current_user)
    false
  end

  def can_update_daily_leading?
    # 活动创建者始终可以更新
    return true if @reading_event.leader == current_user

    # 领读人在权限窗口内可以更新
    return true if @reading_schedule.daily_leader == current_user &&
                    @reading_schedule.can_publish_leading_content?

    false
  end

  def can_delete_daily_leading?
    # 只有活动创建者可以删除
    @reading_event.leader == current_user
  end
end