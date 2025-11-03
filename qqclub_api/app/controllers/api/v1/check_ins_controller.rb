class Api::V1::CheckInsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_check_in, only: [:show, :update, :destroy]
  before_action :check_check_in_permission, only: [:update, :destroy]

  # POST /api/v1/reading_schedules/:reading_schedule_id/check_ins
  # 创建打卡
  def create
    schedule_id = params[:reading_schedule_id]
    schedule = ReadingSchedule.find_by(id: schedule_id)

    unless schedule
      render_error(
        message: '阅读计划不存在',
        code: 'SCHEDULE_NOT_FOUND',
        status: :not_found
      )
      return
    end

    # 检查用户是否已报名该活动
    enrollment = current_user.event_enrollments.find_by(reading_event: schedule.reading_event)
    unless enrollment
      render_error(
        message: '您还未报名该活动',
        code: 'NOT_ENROLLED',
        status: :forbidden
      )
      return
    end

    # 检查活动状态
    unless schedule.reading_event.in_progress?
      render_error(
        message: '活动尚未开始或已结束',
        code: 'EVENT_NOT_ACTIVE',
        status: :unprocessable_entity
      )
      return
    end

    # 检查是否已经打卡
    existing_check_in = CheckIn.find_by(
      user: current_user,
      reading_schedule: schedule
    )

    if existing_check_in
      render_error(
        message: '今日已打卡',
        code: 'ALREADY_CHECKED_IN',
        status: :unprocessable_entity
      )
      return
    end

    # 检查打卡时间窗口
    unless can_check_in?(schedule)
      render_error(
        message: '打卡时间已过，请使用补卡功能',
        code: 'CHECK_IN_TIME_EXPIRED',
        status: :unprocessable_entity
      )
      return
    end

    check_in = CheckIn.new(check_in_params)
    check_in.user = current_user
    check_in.reading_schedule = schedule
    check_in.enrollment = enrollment

    if check_in.save
      render_success(
        data: check_in_response_data(check_in),
        message: '打卡成功'
      )
      log_api_call('check_ins#create')
    else
      render_error(
        message: '打卡失败',
        errors: check_in.errors.full_messages,
        code: 'CHECK_IN_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '阅读计划不存在',
      code: 'SCHEDULE_NOT_FOUND',
      status: :not_found
    )
  rescue => e
    render_error(
      message: '打卡失败',
      errors: [e.message],
      code: 'CHECK_IN_ERROR'
    )
  end

  # GET /api/v1/reading_schedules/:reading_schedule_id/check_ins
  # 获取打卡列表
  def index
    schedule_id = params[:reading_schedule_id]
    schedule = ReadingSchedule.find_by(id: schedule_id)

    unless schedule
      render_error(
        message: '阅读计划不存在',
        code: 'SCHEDULE_NOT_FOUND',
        status: :not_found
      )
      return
    end

    # 检查权限
    unless can_view_check_ins?(schedule)
      render_error(
        message: '权限不足',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    # 分页参数
    page = safe_integer_param(params[:page]) || 1
    per_page = safe_integer_param(params[:per_page]) || 20

    check_ins = schedule.check_ins.includes(:user, :flowers, :comments)
      .order(submitted_at: :desc)
      .page(page)
      .per(per_page)

    render_success(
      data: {
        check_ins: check_ins.map { |ci| check_in_response_data(ci) },
        pagination: {
          current_page: page,
          per_page: per_page,
          total_pages: check_ins.total_pages,
          total_count: check_ins.total_count
        },
        schedule_info: schedule_basic_info(schedule),
        statistics: schedule_check_in_statistics(schedule)
      }
    )
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '阅读计划不存在',
      code: 'SCHEDULE_NOT_FOUND',
      status: :not_found
    )
  rescue => e
    render_error(
      message: '获取打卡列表失败',
      errors: [e.message],
      code: 'GET_CHECK_INS_ERROR'
    )
  end

  # GET /api/v1/check_ins/:id
  # 获取打卡详情
  def show
    format_content = params[:format_content] == 'true'

    render_success(
      data: check_in_response_data(@check_in, detailed: true, format_content: format_content)
    )
  rescue => e
    render_error(
      message: '获取打卡详情失败',
      errors: [e.message],
      code: 'GET_CHECK_IN_ERROR'
    )
  end

  # PUT /api/v1/check_ins/:id
  # 更新打卡
  def update
    # 检查打卡是否可以编辑
    unless @check_in.can_be_edited?
      render_error(
        message: '活动已结束，无法编辑打卡',
        code: 'CANNOT_EDIT',
        status: :unprocessable_entity
      )
      return
    end

    # 检查是否已获得小红花，如果有则给出警告
    if @check_in.flowers.any?
      render_error(
        message: '已获得小红花的打卡修改可能会影响小红花发放者的统计，请谨慎操作。是否继续修改？',
        code: 'HAS_FLOWERS_WARNING',
        status: :unprocessable_entity
      )
      return
    end

    if @check_in.update(check_in_params)
      render_success(
        data: check_in_response_data(@check_in),
        message: '打卡更新成功'
      )
      log_api_call('check_ins#update')
    else
      render_error(
        message: '打卡更新失败',
        errors: @check_in.errors.full_messages,
        code: 'UPDATE_CHECK_IN_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue => e
    render_error(
      message: '打卡更新失败',
      errors: [e.message],
      code: 'UPDATE_CHECK_IN_ERROR'
    )
  end

  # DELETE /api/v1/check_ins/:id
  # 删除打卡
  def destroy
    # 只能删除自己的打卡
    unless @check_in.user == current_user
      render_error(
        message: '只能删除自己的打卡',
        code: 'CANNOT_DELETE_OTHERS',
        status: :forbidden
      )
      return
    end

    # 检查打卡是否可以删除
    unless @check_in.can_be_deleted?
      render_error(
        message: '活动已结束，无法删除打卡',
        code: 'CANNOT_DELETE',
        status: :unprocessable_entity
      )
      return
    end

    # 检查是否已获得小红花，如果有则给出警告
    if @check_in.flowers.any?
      flowers_count = @check_in.flowers.count
      render_error(
        message: "该打卡已获得#{flowers_count}朵小红花，删除后将同时删除这些小红花记录，是否确认删除？",
        code: 'HAS_FLOWERS_WARNING',
        status: :unprocessable_entity
      )
      return
    end

    if @check_in.destroy
      render_success(
        message: '打卡删除成功，相关统计数据已更新'
      )
      log_api_call('check_ins#destroy')
    else
      render_error(
        message: '打卡删除失败',
        code: 'DELETE_CHECK_IN_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue => e
    render_error(
      message: '打卡删除失败',
      errors: [e.message],
      code: 'DELETE_CHECK_IN_ERROR'
    )
  end

  # POST /api/v1/check_ins/:id/submit_late
  # 提交迟到打卡
  def submit_late
    # 检查是否可以编辑（活动是否已结束）
    unless @check_in.can_be_edited?
      render_error(
        message: '活动已结束，无法提交迟到打卡',
        code: 'CANNOT_SUBMIT_LATE',
        status: :unprocessable_entity
      )
      return
    end

    # 更新状态为迟到
    if @check_in.update(status: :late)
      render_success(
        data: check_in_response_data(@check_in),
        message: '迟到打卡提交成功'
      )
      log_api_call('check_ins#submit_late')
    else
      render_error(
        message: '迟到打卡提交失败',
        errors: @check_in.errors.full_messages,
        code: 'SUBMIT_LATE_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue => e
    render_error(
      message: '迟到打卡提交失败',
      errors: [e.message],
      code: 'SUBMIT_LATE_ERROR'
    )
  end

  # POST /api/v1/check_ins/:id/submit_supplement
  # 提交补卡
  def submit_supplement
    # 检查是否可以编辑（活动是否已结束）
    unless @check_in.can_be_edited?
      render_error(
        message: '活动已结束，无法提交补卡',
        code: 'CANNOT_MAKEUP',
        status: :unprocessable_entity
      )
      return
    end

    # 检查是否可以补卡（基于日期和活动状态）
    unless @check_in.can_makeup?
      render_error(
        message: '该打卡不适用补卡功能',
        code: 'CANNOT_MAKEUP',
        status: :unprocessable_entity
      )
      return
    end

    # 更新状态为补卡
    if @check_in.update(status: :supplement)
      render_success(
        data: check_in_response_data(@check_in),
        message: '补卡提交成功'
      )
      log_api_call('check_ins#submit_supplement')
    else
      render_error(
        message: '补卡提交失败',
        errors: @check_in.errors.full_messages,
        code: 'SUBMIT_SUPPLEMENT_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue => e
    render_error(
      message: '补卡提交失败',
      errors: [e.message],
      code: 'SUBMIT_SUPPLEMENT_ERROR'
    )
  end

  # GET /api/v1/users/:user_id/check_ins
  # 获取用户的打卡记录
  def user_check_ins
    user_id = safe_integer_param(params[:user_id])
    user = user_id ? User.find_by(id: user_id) : current_user

    unless user
      render_error(
        message: '用户不存在',
        code: 'USER_NOT_FOUND',
        status: :not_found
      )
      return
    end

    # 检查权限（只能查看自己的打卡，除非是管理员）
    unless user == current_user || current_user.can_approve_events?
      render_error(
        message: '权限不足',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    # 分页参数
    page = safe_integer_param(params[:page]) || 1
    per_page = safe_integer_param(params[:per_page]) || 20

    # 筛选参数
    status_filter = params[:status]
    start_date = parse_date_param(params[:start_date])
    end_date = parse_date_param(params[:end_date])

    check_ins = user.check_ins.includes(:reading_schedule, :flowers, :comments)
      .joins(:reading_schedule)

    # 应用筛选条件
    check_ins = check_ins.where(status: status_filter) if status_filter.present?
    check_ins = check_ins.where('reading_schedules.date >= ?', start_date) if start_date.present?
    check_ins = check_ins.where('reading_schedules.date <= ?', end_date) if end_date.present?

    check_ins = check_ins.order(submitted_at: :desc)
      .page(page)
      .per(per_page)

    render_success(
      data: {
        check_ins: check_ins.map { |ci| check_in_response_data(ci) },
        pagination: {
          current_page: page,
          per_page: per_page,
          total_pages: check_ins.total_pages,
          total_count: check_ins.total_count
        },
        user: user_info(user),
        statistics: user_check_in_statistics(user)
      }
    )
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '用户不存在',
      code: 'USER_NOT_FOUND',
      status: :not_found
    )
  rescue => e
    render_error(
      message: '获取用户打卡记录失败',
      errors: [e.message],
      code: 'GET_USER_CHECK_INS_ERROR'
    )
  end

  # GET /api/v1/check_ins/statistics
  # 获取打卡统计
  def statistics
    # 统计参数
    event_id = safe_integer_param(params[:event_id])
    schedule_id = safe_integer_param(params[:schedule_id])
    date_range = params[:date_range] # today, week, month

    base_query = CheckIn.includes(:user, :reading_schedule)

    # 应用筛选条件
    if event_id
      event = ReadingEvent.find_by(id: event_id)
      base_query = base_query.joins(:reading_schedule).where(reading_schedules: { reading_event_id: event_id })
    end

    if schedule_id
      base_query = base_query.where(reading_schedule_id: schedule_id)
    end

    case date_range
    when 'today'
      base_query = base_query.joins(:reading_schedule).where(reading_schedules: { date: Date.current })
    when 'week'
      base_query = base_query.joins(:reading_schedule).where(reading_schedules: { date: Date.current.beginning_of_week..Date.current.end_of_week })
    when 'month'
      base_query = base_query.joins(:reading_schedule).where(reading_schedules: { date: Date.current.beginning_of_month..Date.current.end_of_month })
    end

    total_check_ins = base_query.count
    normal_check_ins = base_query.where(status: :normal).count
    supplement_check_ins = base_query.where(status: :supplement).count
    late_check_ins = base_query.where(status: :late).count

    # 用户统计
    user_stats = base_query.group(:user_id).count
    active_users = user_stats.size

    # 内容统计
    total_words = base_query.sum(:word_count)
    avg_words = total_check_ins > 0 ? (total_words.to_f / total_check_ins).round(2) : 0

    # 小红花统计
    flowers_stats = base_query.joins(:flowers).group(:check_in_id).count

    render_success(
      data: {
        total_check_ins: total_check_ins,
        normal_check_ins: normal_check_ins,
        supplement_check_ins: supplement_check_ins,
        late_check_ins: late_check_ins,
        active_users: active_users,
        total_words: total_words,
        average_words: avg_words,
        flowers_given: flowers_stats.size,
        date_range: date_range,
        event_id: event_id,
        schedule_id: schedule_id
      }
    )
  rescue => e
    render_error(
      message: '获取打卡统计失败',
      errors: [e.message],
      code: 'GET_CHECK_INS_STATISTICS_ERROR'
    )
  end

  private

  def set_check_in
    @check_in = CheckIn.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '打卡记录不存在',
      code: 'CHECK_IN_NOT_FOUND',
      status: :not_found
    )
  end

  def check_check_in_permission
    unless @check_in.user == current_user
      render_error(
        message: '只能操作自己的打卡',
        code: 'PERMISSION_DENIED',
        status: :forbidden
      )
    end
  end

  def can_check_in?(schedule)
    return true unless schedule # 防止nil错误

    schedule_date = schedule.date
    current_time = Time.current

    # 当天的打卡可以在晚上11:59前提交
    if schedule_date == Date.current
      return current_time <= schedule_date.to_time.end_of_day
    end

    # 过去的日期可以补卡
    schedule_date < Date.current && schedule.reading_event.in_progress?
  end

  def can_view_check_ins?(schedule)
    # 活动参与者可以查看
    return true if current_user.enrolled?(schedule.reading_event)

    # 活动创建者可以查看
    return true if schedule.reading_event.leader == current_user

    # 领读人可以查看
    if schedule.daily_leader == current_user || schedule.reading_event.current_daily_leader?(current_user, schedule)
      return true
    end

    # 管理员可以查看
    current_user.can_approve_events?
  end

  def check_in_params
    params.require(:check_in).permit(:content, :word_count, :status)
  end

  def check_in_response_data(check_in, detailed: false, format_content: false)
    base_data = {
      id: check_in.id,
      user: user_info(check_in.user),
      reading_schedule: {
        id: check_in.reading_schedule.id,
        day_number: check_in.reading_schedule.day_number,
        date: check_in.reading_schedule.date,
        reading_progress: check_in.reading_schedule.reading_progress
      },
      content: check_in.content,
      formatted_content: format_content ? check_in.formatted_content : nil,
      content_preview: check_in.content_preview(150),
      word_count: check_in.word_count,
      status: check_in.status,
      submitted_at: check_in.submitted_at,
      updated_at: check_in.updated_at,
      flowers_count: check_in.flowers_count,
      engagement_score: check_in.engagement_score,
      quality_score: check_in.quality_score,
      keywords: check_in.keywords(5),
      reading_time: check_in.reading_time_estimate,
      can_be_edited: check_in.can_be_edited?,
      can_receive_flowers: check_in.can_receive_flowers?,
      high_quality: check_in.high_quality?,
      has_formatting_issues: check_in.has_formatting_issues?,
      contains_sensitive_words: check_in.contains_sensitive_words?
    }

    if detailed
      base_data[:flowers] = check_in.flowers.map { |flower| flower_response_data(flower) }
      base_data[:comments_count] = check_in.comments.count
      base_data[:reading_event] = {
        id: check_in.reading_event&.id,
        title: check_in.reading_event&.title
      }
      base_data[:enrollment] = {
        id: check_in.enrollment&.id,
        completion_rate: check_in.enrollment&.completion_rate
      }
      base_data[:content_summary] = check_in.content_summary(200)
      base_data[:compliance_check] = check_in.compliance_check
    end

    base_data
  end

  def flower_response_data(flower)
    {
      id: flower.id,
      giver: user_info(flower.giver),
      comment: flower.comment,
      amount: flower.amount,
      created_at: flower.created_at
    }
  end

  def user_info(user)
    return nil unless user

    {
      id: user.id,
      nickname: user.nickname,
      avatar_url: user.avatar_url
    }
  end

  def schedule_basic_info(schedule)
    {
      id: schedule.id,
      day_number: schedule.day_number,
      date: schedule.date,
      reading_progress: schedule.reading_progress,
      daily_leader: schedule.daily_leader ? user_info(schedule.daily_leader) : nil
    }
  end

  def schedule_check_in_statistics(schedule)
    check_ins = schedule.check_ins
    total = check_ins.count
    today = check_ins.today.count

    {
      total: total,
      today: today,
      normal: check_ins.normal.count,
      supplement: check_ins.supplement.count,
      late: check_ins.late.count,
      total_words: check_ins.sum(:word_count),
      average_words: total > 0 ? (check_ins.sum(:word_count).to_f / total).round(2) : 0,
      flowers_given: check_ins.joins(:flowers).count
    }
  end

  def user_check_in_statistics(user)
    check_ins = user.check_ins.includes(:reading_schedule)

    total_check_ins = check_ins.count
    this_month = check_ins.joins(:reading_schedule)
      .where('reading_schedules.date >= ?', Date.current.beginning_of_month)
      .count

    {
      total_check_ins: total_check_ins,
      this_month: this_month,
      current_streak: calculate_current_streak(user),
      longest_streak: calculate_longest_streak(user),
      total_words: check_ins.sum(:word_count),
      average_words: total_check_ins > 0 ? (check_ins.sum(:word_count).to_f / total_check_ins).round(2) : 0,
      flowers_received: user.flowers_received_count || 0,
      engagement_score: user.check_ins.average(:engagement_score)&.round(2) || 0
    }
  end

  def calculate_current_streak(user)
    # 计算当前连续打卡天数
    streak = 0
    date = Date.current

    while date >= Date.current - 30.days # 最多计算30天
      if user.check_ins.joins(:reading_schedule).where('reading_schedules.date = ?', date).exists?
        streak += 1
        date -= 1.day
      else
        break
      end
    end

    streak
  end

  def calculate_longest_streak(user)
    # 计算历史最长连续打卡天数
    # 这里可以优化为更高效的算法
    check_in_dates = user.check_ins.joins(:reading_schedule)
      .pluck('reading_schedules.date')
      .sort.uniq

    return 0 if check_in_dates.empty?

    longest_streak = 1
    current_streak = 1

    check_in_dates.each_cons do |date1, date2|
      if date2 == date1 + 1.day
        current_streak += 1
        longest_streak = [longest_streak, current_streak].max
      else
        current_streak = 1
      end
    end

    longest_streak
  end

  # 辅助方法
  def safe_integer_param(param)
    return nil if param.blank?

    Integer(param)
  rescue ArgumentError, TypeError
    nil
  end

  def parse_date_param(param)
    return nil if param.blank?

    Date.parse(param.to_s)
  rescue ArgumentError, TypeError
    nil
  end
end