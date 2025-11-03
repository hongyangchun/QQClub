class Api::V1::ContentExportController < Api::V1::BaseController
  before_action :authenticate_user!

  # GET /api/v1/content_export/statistics
  # 导出统计信息
  def statistics
    export_params = build_export_params

    stats = ContentExportService.export_statistics(export_params)

    render_success(
      data: stats,
      message: '导出统计信息获取成功'
    )
  rescue => e
    render_error(
      message: '获取导出统计信息失败',
      errors: [e.message],
      code: 'EXPORT_STATISTICS_ERROR'
    )
  end

  # GET /api/v1/content_export/preview
  # 导出预览
  def preview
    export_params = build_export_params

    # 限制预览数量
    export_params[:limit] = 5

    check_ins = get_check_ins_for_preview(export_params)

    render_success(
      data: {
        check_ins: check_ins.map(&:to_search_result_h),
        total_count: estimate_total_count(export_params),
        preview: true,
        limit: 5
      },
      message: '导出预览生成成功'
    )
  rescue => e
    render_error(
      message: '生成导出预览失败',
      errors: [e.message],
      code: 'EXPORT_PREVIEW_ERROR'
    )
  end

  # GET /api/v1/content_export/export
  # 执行导出
  def export
    export_params = build_export_params

    # 验证导出权限
    unless can_export_content?(export_params)
      render_error(
        message: '权限不足，无法导出这些内容',
        code: 'EXPORT_PERMISSION_DENIED',
        status: :forbidden
      )
      return
    end

    # 执行导出
    result = ContentExportService.export(export_params)

    if result.success?
      # 记录导出操作
      log_export_operation(export_params, result)

      send_data result.content,
                filename: result.filename,
                type: result.content_type,
                disposition: 'attachment'
    else
      render_error(
        message: '导出失败',
        errors: [result.content],
        code: 'EXPORT_FAILED'
      )
    end
  rescue => e
    render_error(
      message: '导出过程中发生错误',
      errors: [e.message],
      code: 'EXPORT_ERROR'
    )
  end

  # POST /api/v1/content_export/batch_export
  # 批量导出
  def batch_export
    export_requests = params[:export_requests]

    unless export_requests.is_a?(Array) && export_requests.any?
      render_error(
        message: '请提供导出请求列表',
        code: 'INVALID_EXPORT_REQUESTS',
        status: :unprocessable_entity
      )
      return
    end

    # 验证批量导出权限
    unless current_user.can_approve_events? # 只有管理员可以批量导出
      render_error(
        message: '权限不足，只有管理员可以批量导出',
        code: 'BATCH_EXPORT_PERMISSION_DENIED',
        status: :forbidden
      )
      return
    end

    # 执行批量导出
    results = ContentExportService.batch_export(export_requests)

    # 记录批量导出操作
    log_batch_export_operation(export_requests, results)

    render_success(
      data: {
        results: results.map { |result| export_result_to_h(result) },
        total_requests: export_requests.count,
        successful_exports: results.count(&:success?),
        failed_exports: results.count { |r| !r.success? }
      },
      message: '批量导出完成'
    )
  rescue => e
    render_error(
      message: '批量导出过程中发生错误',
      errors: [e.message],
      code: 'BATCH_EXPORT_ERROR'
    )
  end

  # GET /api/v1/content_export/templates
  # 获取导出模板
  def templates
    templates = [
      {
        id: 'personal',
        name: '个人打卡记录',
        description: '导出当前用户的所有打卡记录',
        params: {
          format: 'pdf',
          include_metadata: true,
          include_comments: true,
          include_flowers: true,
          sort_by: 'created_at',
          sort_direction: 'desc'
        }
      },
      {
        id: 'event_summary',
        name: '活动汇总报告',
        description: '导出指定活动的所有打卡记录汇总',
        params: {
          format: 'pdf',
          include_metadata: true,
          include_comments: false,
          include_flowers: true,
          sort_by: 'created_at',
          sort_direction: 'asc'
        }
      },
      {
        id: 'quality_content',
        name: '高质量内容精选',
        description: '导出所有高质量打卡内容',
        params: {
          format: 'markdown',
          include_metadata: true,
          include_comments: true,
          include_flowers: true,
          sort_by: 'quality_score',
          sort_direction: 'desc'
        }
      },
      {
        id: 'data_analysis',
        name: '数据分析报告',
        description: '导出用于数据分析的CSV格式数据',
        params: {
          format: 'csv',
          include_metadata: false,
          include_comments: false,
          include_flowers: true,
          sort_by: 'created_at',
          sort_direction: 'asc'
        }
      }
    ]

    render_success(
      data: templates,
      message: '导出模板获取成功'
    )
  end

  # POST /api/v1/content_export/save_template
  # 保存自定义模板
  def save_template
    template_name = params[:name]
    template_params = params[:template]

    if template_name.blank? || template_params.blank?
      render_error(
        message: '模板名称和参数不能为空',
        code: 'INVALID_TEMPLATE',
        status: :unprocessable_entity
      )
      return
    end

    # 这里可以实现保存模板到数据库的逻辑
    # 暂时返回成功响应

    render_success(
      message: '模板保存成功'
    )
    log_api_call('content_export#save_template')
  rescue => e
    render_error(
      message: '保存模板失败',
      errors: [e.message],
      code: 'SAVE_TEMPLATE_ERROR'
    )
  end

  # GET /api/v1/content_export/history
  # 导出历史
  def export_history
    limit = safe_integer_param(params[:limit]) || 20

    # 这里可以实现获取用户导出历史的逻辑
    # 暂时返回空数组
    history_items = []

    render_success(
      data: {
        history: history_items,
        limit: limit
      },
      message: '导出历史获取成功'
    )
  rescue => e
    render_error(
      message: '获取导出历史失败',
      errors: [e.message],
      code: 'EXPORT_HISTORY_ERROR'
    )
  end

  # POST /api/v1/content_export/schedule
  # 定时导出
  def schedule_export
    export_params = build_export_params
    schedule_time = params[:schedule_time]
    schedule_type = params[:schedule_type] || 'once' # once, daily, weekly, monthly

    unless schedule_time.present?
      render_error(
        message: '请提供导出时间',
        code: 'SCHEDULE_TIME_REQUIRED',
        status: :unprocessable_entity
      )
      return
    end

    # 这里可以实现定时导出的逻辑
    # 暂时返回成功响应

    render_success(
      message: '定时导出设置成功'
    )
    log_api_call('content_export#schedule_export')
  rescue => e
    render_error(
      message: '设置定时导出失败',
      errors: [e.message],
      code: 'SCHEDULE_EXPORT_ERROR'
    )
  end

  private

  # 构建导出参数
  def build_export_params
    permitted_params = params.permit(
      :format, :check_in_ids, :user_id, :event_id, :date_from, :date_to,
      :include_metadata, :include_comments, :include_flowers,
      :sort_by, :sort_direction, :template, :limit
    ).to_h

    # 设置默认值
    permitted_params[:format] ||= 'pdf'
    permitted_params[:include_metadata] = true if permitted_params[:include_metadata].nil?
    permitted_params[:sort_by] ||= 'created_at'
    permitted_params[:sort_direction] ||= 'desc'

    permitted_params
  end

  # 检查导出权限
  def can_export_content?(export_params)
    # 用户可以导出自己的内容
    return true if export_params[:user_id].blank? || export_params[:user_id] == current_user.id

    # 管理员可以导出任何内容
    return true if current_user.can_approve_events?

    # 活动领读人可以导出自己活动的内容
    if export_params[:event_id].present?
      event = ReadingEvent.find_by(id: export_params[:event_id])
      return true if event&.leader == current_user
    end

    false
  end

  # 获取预览用的打卡记录
  def get_check_ins_for_preview(export_params)
    query = CheckIn.includes(:user, :reading_schedule, :reading_event)

    # 应用筛选条件（简化版）
    if export_params[:user_id].present?
      query = query.where(user_id: export_params[:user_id])
    end

    if export_params[:event_id].present?
      query = query.joins(:reading_schedule).where(reading_schedules: { reading_event_id: export_params[:event_id] })
    end

    if export_params[:date_from].present?
      query = query.where('check_ins.created_at >= ?', export_params[:date_from].beginning_of_day)
    end

    if export_params[:date_to].present?
      query = query.where('check_ins.created_at <= ?', export_params[:date_to].end_of_day)
    end

    # 限制数量并排序
    query.limit(export_params[:limit] || 5).order(created_at: :desc)
  end

  # 估算总数量
  def estimate_total_count(export_params)
    query = CheckIn.all

    # 应用相同的筛选条件
    if export_params[:user_id].present?
      query = query.where(user_id: export_params[:user_id])
    end

    if export_params[:event_id].present?
      query = query.joins(:reading_schedule).where(reading_schedules: { reading_event_id: export_params[:event_id] })
    end

    if export_params[:date_from].present?
      query = query.where('check_ins.created_at >= ?', export_params[:date_from].beginning_of_day)
    end

    if export_params[:date_to].present?
      query = query.where('check_ins.created_at <= ?', export_params[:date_to].end_of_day)
    end

    query.count
  end

  # 记录导出操作
  def log_export_operation(export_params, result)
    # 这里可以实现导出操作的记录逻辑
    # 例如：保存到数据库、发送通知等
    log_api_call('content_export#export', {
      format: export_params[:format],
      check_ins_count: result.check_ins_count,
      filename: result.filename
    })
  end

  # 记录批量导出操作
  def log_batch_export_operation(export_requests, results)
    log_api_call('content_export#batch_export', {
      total_requests: export_requests.count,
      successful_exports: results.count(&:success?),
      failed_exports: results.count { |r| !r.success? }
    })
  end

  # 转换导出结果为哈希
  def export_result_to_h(result)
    {
      filename: result.filename,
      content_type: result.content_type,
      size: result.size,
      check_ins_count: result.check_ins_count,
      success: result.success?
    }
  end

  # 辅助方法
  def safe_integer_param(param)
    return nil if param.blank?
    Integer(param)
  rescue ArgumentError, TypeError
    nil
  end
end