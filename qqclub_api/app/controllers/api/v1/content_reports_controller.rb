class Api::V1::ContentReportsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_check_in, only: [:create]
  before_action :set_report, only: [:show, :update]
  before_action :check_admin_permissions, only: [:index, :update, :batch_process, :statistics, :export]

  # POST /api/v1/content_reports
  # 创建举报
  def create
    reason = params[:reason]
    description = params[:description]

    if reason.blank?
      render_error(
        message: '请选择举报原因',
        code: 'MISSING_REASON',
        status: :unprocessable_entity
      )
      return
    end

    # 验证举报原因
    unless ContentReport.reasons.key?(reason.to_sym)
      render_error(
        message: '无效的举报原因',
        code: 'INVALID_REASON',
        status: :unprocessable_entity
      )
      return
    end

    # 创建举报
    result = ContentModerationService.create_report(
      current_user,
      @check_in,
      reason: reason.to_sym,
      description: description
    )

    if result[:success]
      render_success(
        data: content_report_response_data(result[:report]),
        message: result[:message]
      )
      log_api_call('content_reports#create')
    else
      render_error(
        message: result[:error],
        errors: result[:errors],
        code: 'REPORT_CREATE_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue => e
    render_error(
      message: '提交举报失败',
      errors: [e.message],
      code: 'REPORT_CREATE_ERROR'
    )
  end

  # GET /api/v1/content_reports
  # 获取举报列表（管理员）
  def index
    page = safe_integer_param(params[:page]) || 1
    per_page = safe_integer_param(params[:per_page]) || 20

    # 筛选参数
    status = params[:status]
    reason = params[:reason]
    user_id = safe_integer_param(params[:user_id])
    check_in_id = safe_integer_param(params[:check_in_id])

    reports = ContentReport.includes(:user, :check_in, :admin)
                                 .order(created_at: :desc)

    # 应用筛选
    reports = reports.where(status: status) if status.present?
    reports = reports.where(reason: reason) if reason.present?
    reports = reports.where(user_id: user_id) if user_id.present?
    reports = reports.where(check_in_id: check_in_id) if check_in_id.present?

    # 分页
    paginated_reports = reports.page(page).per(per_page)

    render_success(
      data: {
        reports: paginated_reports.map { |report| content_report_response_data(report, detailed: true) },
        pagination: {
          current_page: page,
          per_page: per_page,
          total_pages: paginated_reports.total_pages,
          total_count: paginated_reports.total_count
        },
        filters: {
          status: status,
          reason: reason,
          user_id: user_id,
          check_in_id: check_in_id
        }
      },
      message: '举报列表获取成功'
    )
    log_api_call('content_reports#index')
  rescue => e
    render_error(
      message: '获取举报列表失败',
      errors: [e.message],
      code: 'REPORTS_LIST_ERROR'
    )
  end

  # GET /api/v1/content_reports/:id
  # 获取举报详情
  def show
    unless @report.user == current_user || current_user.can_approve_events?
      render_error(
        message: '权限不足',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    render_success(
      data: content_report_response_data(@report, detailed: true),
      message: '举报详情获取成功'
    )
  rescue => e
    render_error(
      message: '获取举报详情失败',
      errors: [e.message],
      code: 'REPORT_SHOW_ERROR'
    )
  end

  # PUT /api/v1/content_reports/:id
  # 处理举报（管理员）
  def update
    action = params[:action]
    notes = params[:notes]

    if action.blank?
      render_error(
        message: '请选择处理动作',
        code: 'MISSING_ACTION',
        status: :unprocessable_entity
      )
      return
    end

    # 验证处理动作
    valid_actions = %w[reviewed dismissed action_taken]
    unless valid_actions.include?(action)
      render_error(
        message: '无效的处理动作',
        code: 'INVALID_ACTION',
        status: :unprocessable_entity
      )
      return
    end

    # 处理举报
    result = @report.review!(
      admin: current_user,
      notes: notes,
      action: action.to_sym
    )

    if result
      render_success(
        data: content_report_response_data(@report, detailed: true),
        message: '举报处理成功'
      )
      log_api_call('content_reports#update')
    else
      render_error(
        message: '举报处理失败',
        code: 'REPORT_UPDATE_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue => e
    render_error(
      message: '处理举报失败',
      errors: [e.message],
      code: 'REPORT_UPDATE_ERROR'
    )
  end

  # POST /api/v1/content_reports/batch_process
  # 批量处理举报（管理员）
  def batch_process
    report_ids = params[:report_ids]
    action = params[:action]
    notes = params[:notes]

    if report_ids.blank? || !report_ids.is_a?(Array)
      render_error(
        message: '请提供举报ID列表',
        code: 'MISSING_REPORT_IDS',
        status: :unprocessable_entity
      )
      return
    end

    if action.blank?
      render_error(
        message: '请选择处理动作',
        code: 'MISSING_ACTION',
        status: :unprocessable_entity
      )
      return
    end

    # 验证处理动作
    valid_actions = %w[reviewed dismissed action_taken]
    unless valid_actions.include?(action)
      render_error(
        message: '无效的处理动作',
        code: 'INVALID_ACTION',
        status: :unprocessable_entity
      )
      return
    end

    # 批量处理
    result = ContentModerationService.batch_process_reports(
      current_user,
      report_ids,
      action: action.to_sym,
      notes: notes
    )

    if result[:success]
      render_success(
        data: result,
        message: "批量处理完成：成功处理 #{result[:processed_count]}/#{result[:total_count]} 个举报"
      )
      log_api_call('content_reports#batch_process')
    else
      render_error(
        message: result[:error],
        code: 'BATCH_PROCESS_FAILED'
      )
    end
  rescue => e
    render_error(
      message: '批量处理失败',
      errors: [e.message],
      code: 'BATCH_PROCESS_ERROR'
    )
  end

  # GET /api/v1/content_reports/statistics
  # 获取举报统计（管理员）
  def statistics
    days = safe_integer_param(params[:days]) || 30

    stats = ContentModerationService.get_statistics(days)

    render_success(
      data: stats,
      message: '举报统计获取成功'
    )
    log_api_call('content_reports#statistics')
  rescue => e
    render_error(
      message: '获取举报统计失败',
      errors: [e.message],
      code: 'STATISTICS_ERROR'
    )
  end

  # GET /api/v1/content_reports/pending
  # 获取待处理举报（管理员）
  def pending
    limit = safe_integer_param(params[:limit]) || 50

    reports = ContentModerationService.get_pending_reports(limit: limit)

    render_success(
      data: {
        reports: reports.map { |report| content_report_response_data(report, detailed: true) },
        count: reports.count,
        limit: limit
      },
      message: '待处理举报列表获取成功'
    )
    log_api_call('content_reports#pending')
  rescue => e
    render_error(
      message: '获取待处理举报失败',
      errors: [e.message],
      code: 'PENDING_REPORTS_ERROR'
    )
  end

  # GET /api/v1/content_reports/high_priority
  # 获取高优先级举报（管理员）
  def high_priority
    reports = ContentModerationService.get_high_priority_reports

    render_success(
      data: {
        reports: reports.map { |report| content_report_response_data(report, detailed: true) },
        count: reports.count
      },
      message: '高优先级举报列表获取成功'
    )
    log_api_call('content_reports#high_priority')
  rescue => e
    render_error(
      message: '获取高优先级举报失败',
      errors: [e.message],
      code: 'HIGH_PRIORITY_REPORTS_ERROR'
    )
  end

  # GET /api/v1/content_reports/export
  # 导出举报数据（管理员）
  def export
    start_date = parse_date_param(params[:start_date]) || 30.days.ago.to_date
    end_date = parse_date_param(params[:end_date]) || Date.current

    report = ContentModerationService.generate_moderation_report(start_date, end_date)

    render_success(
      data: report,
      message: '举报报告生成成功'
    )
    log_api_call('content_reports#export')
  rescue => e
    render_error(
      message: '导出举报数据失败',
      errors: [e.message],
      code: 'EXPORT_ERROR'
    )
  end

  # GET /api/v1/content_reports/my_reports
  # 获取我的举报历史
  def my_reports
    page = safe_integer_param(params[:page]) || 1
    per_page = safe_integer_param(params[:per_page]) || 20

    reports = current_user.content_reports
                          .includes(:check_in, :admin)
                          .order(created_at: :desc)
                          .page(page)
                          .per(per_page)

    render_success(
      data: {
        reports: reports.map { |report| content_report_response_data(report, detailed: true) },
        pagination: {
          current_page: page,
          per_page: per_page,
          total_pages: reports.total_pages,
          total_count: reports.total_count
        }
      },
      message: '我的举报历史获取成功'
    )
    log_api_call('content_reports#my_reports')
  rescue => e
    render_error(
      message: '获取举报历史失败',
      errors: [e.message],
      code: 'MY_REPORTS_ERROR'
    )
  end

  private

  def set_check_in
    check_in_id = safe_integer_param(params[:check_in_id])

    unless check_in_id
      render_error(
        message: '打卡ID不能为空',
        code: 'MISSING_CHECK_IN_ID',
        status: :unprocessable_entity
      )
      return
    end

    @check_in = CheckIn.find_by(id: check_in_id)

    unless @check_in
      render_error(
        message: '打卡不存在',
        code: 'CHECK_IN_NOT_FOUND',
        status: :not_found
      )
      return
    end
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '打卡不存在',
      code: 'CHECK_IN_NOT_FOUND',
      status: :not_found
    )
  end

  def set_report
    @report = ContentReport.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '举报记录不存在',
      code: 'REPORT_NOT_FOUND',
      status: :not_found
    )
  end

  def check_admin_permissions
    unless current_user.can_approve_events?
      render_error(
        message: '权限不足',
        code: 'FORBIDDEN',
        status: :forbidden
      )
    end
  end

  def content_report_response_data(report, detailed: false)
    base_data = {
      id: report.id,
      reason: report.reason,
      reason_text: report.reason_text,
      description: report.description,
      status: report.status,
      status_text: report.status_text,
      created_at: report.created_at,
      updated_at: report.updated_at
    }

    if detailed
      base_data[:user] = {
        id: report.user.id,
        nickname: report.user.nickname,
        avatar_url: report.user.avatar_url
      }
      base_data[:check_in] = {
        id: report.check_in.id,
        content: report.check_in.content_preview(200),
        created_at: report.check_in.created_at,
        user: {
          id: report.check_in.user.id,
          nickname: report.check_in.user.nickname
        }
      }
      base_data[:admin] = report.admin ? {
        id: report.admin.id,
        nickname: report.admin.nickname
      } : nil
      base_data[:admin_notes] = report.admin_notes
      base_data[:reviewed_at] = report.reviewed_at
    end

    base_data
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