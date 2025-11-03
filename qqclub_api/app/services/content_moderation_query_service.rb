# frozen_string_literal: true

# ContentModerationQueryService - 内容审核查询服务
# 专门负责举报相关数据的查询和检索
class ContentModerationQueryService < ApplicationService
  include ServiceInterface
  attr_reader :current_user, :filters, :pagination_options

  def initialize(current_user: nil, filters: {}, pagination_options: {})
    super()
    @current_user = current_user
    @filters = filters.with_indifferent_access
    @pagination_options = pagination_options.with_indifferent_access
  end

  # 获取待处理的举报
  def call
    handle_errors do
      validate_query_permissions
      apply_filters_and_paginate
      format_query_results
    end
    self
  end

  # 类方法：获取待处理的举报
  def self.get_pending_reports(limit: 50, current_user: nil)
    new(
      current_user: current_user,
      filters: { status: 'pending' },
      pagination_options: { limit: limit }
    ).call
  end

  # 类方法：获取高优先级举报
  def self.get_high_priority_reports(current_user: nil)
    new(
      current_user: current_user,
      filters: { priority: 'high' }
    ).call
  end

  # 类方法：获取用户举报历史
  def self.get_user_report_history(user, limit: 20, current_user: nil)
    new(
      current_user: current_user,
      filters: { user_id: user.id },
      pagination_options: { limit: limit }
    ).call
  end

  # 类方法：获取被举报的内容
  def self.get_reported_content(limit: 50, status: nil, current_user: nil)
    query_filters = { limit: limit }
    query_filters[:status] = status if status.present?

    new(
      current_user: current_user,
      filters: query_filters
    ).get_reported_content_data
  end

  # 类方法：搜索举报
  def self.search_reports(query, current_user: nil)
    new(
      current_user: current_user,
      filters: { search: query }
    ).call
  end

  private

  # 验证查询权限
  def validate_query_permissions
    # 检查用户是否有权限查看举报数据
    if current_user && !current_user.can_approve_events? && !user_querying_own_reports?
      failure!("无权限查看举报数据")
      return false
    end

    true
  end

  # 检查是否查询自己的举报
  def user_querying_own_reports?
    filters[:user_id] == current_user&.id
  end

  # 应用过滤器和分页
  def apply_filters_and_paginate
    @reports = base_query

    # 应用各种过滤器
    apply_status_filter
    apply_reason_filter
    apply_user_filter
    apply_admin_filter
    apply_date_filter
    apply_priority_filter
    apply_search_filter

    # 应用排序
    apply_ordering

    # 应用分页
    apply_pagination

    true
  end

  # 基础查询
  def base_query
    ContentReport.includes(:user, :admin, :target_content)
  end

  # 应用状态过滤器
  def apply_status_filter
    return unless filters[:status].present?

    status_value = filters[:status]
    case status_value
    when 'pending'
      @reports = @reports.where(status: :pending)
    when 'processed'
      @reports = @reports.where.not(status: :pending)
    when 'approved'
      @reports = @reports.where(status: :approved)
    when 'rejected'
      @reports = @reports.where(status: :rejected)
    else
      @reports = @reports.where(status: status_value)
    end
  end

  # 应用原因过滤器
  def apply_reason_filter
    return unless filters[:reason].present?
    @reports = @reports.where(reason: filters[:reason])
  end

  # 应用用户过滤器
  def apply_user_filter
    return unless filters[:user_id].present?
    @reports = @reports.where(user_id: filters[:user_id])
  end

  # 应用管理员过滤器
  def apply_admin_filter
    return unless filters[:admin_id].present?
    @reports = @reports.where(admin_id: filters[:admin_id])
  end

  # 应用日期过滤器
  def apply_date_filter
    if filters[:start_date].present?
      start_date = Date.parse(filters[:start_date])
      @reports = @reports.where('created_at >= ?', start_date.beginning_of_day)
    end

    if filters[:end_date].present?
      end_date = Date.parse(filters[:end_date])
      @reports = @reports.where('created_at <= ?', end_date.end_of_day)
    end

    if filters[:days_ago].present?
      days_ago = filters[:days_ago].to_i
      @reports = @reports.where('created_at >= ?', days_ago.days.ago)
    end
  end

  # 应用优先级过滤器
  def apply_priority_filter
    return unless filters[:priority].present?

    case filters[:priority]
    when 'high'
      @reports = @reports.where(reason: %w[sensitive_words harassment])
    when 'medium'
      @reports = @reports.where(reason: %w[inappropriate_content spam])
    when 'low'
      @reports = @reports.where(reason: %w[other])
    end
  end

  # 应用搜索过滤器
  def apply_search_filter
    return unless filters[:search].present?

    search_term = "%#{filters[:search]}%"
    @reports = @reports.joins(:user, :target_content)
                     .where(
                       'users.nickname ILIKE ? OR target_contents.content ILIKE ? OR content_reports.description ILIKE ?',
                       search_term, search_term, search_term
                     )
  end

  # 应用排序
  def apply_ordering
    sort_field = filters[:sort_by] || 'created_at'
    sort_direction = filters[:sort_direction] || 'desc'

    valid_fields = %w[created_at updated_at reason status user_id admin_id]
    if valid_fields.include?(sort_field)
      @reports = @reports.order(sort_field => sort_direction)
    else
      @reports = @reports.order(created_at: :desc)
    end
  end

  # 应用分页
  def apply_pagination
    limit = pagination_options[:limit] || 20
    page = pagination_options[:page] || 1
    offset = (page.to_i - 1) * limit.to_i

    @reports = @reports.limit(limit).offset(offset)

    # 记录分页信息用于响应
    @pagination_info = {
      current_page: page.to_i,
      per_page: limit.to_i,
      total_count: @reports.count,
      has_next_page: (@reports.count > (page.to_i * limit.to_i))
    }
  end

  # 格式化查询结果
  def format_query_results
    reports_data = @reports.map do |report|
      format_single_report(report)
    end

    response_data = {
      reports: reports_data
    }

    # 添加分页信息
    response_data[:pagination] = @pagination_info if @pagination_info

    # 添加统计信息
    response_data[:summary] = generate_query_summary if filters[:include_summary]

    success!(response_data)
  end

  # 格式化单个举报数据
  def format_single_report(report)
    {
      id: report.id,
      reason: report.reason,
      description: report.description,
      status: report.status,
      created_at: report.created_at,
      updated_at: report.updated_at,
      reporter: format_user_data(report.user),
      admin: format_user_data(report.admin),
      target_content: format_target_content(report.target_content),
      auto_processed: report.auto_processed?,
      processing_notes: report.notes
    }
  end

  # 格式化用户数据
  def format_user_data(user)
    return nil unless user

    {
      id: user.id,
      nickname: user.nickname,
      avatar_url: user.avatar_url,
      role: user.role_display_name
    }
  end

  # 格式化目标内容数据
  def format_target_content(content)
    return nil unless content

    {
      id: content.id,
      type: content.class.name,
      content_preview: content.respond_to?(:content) ? content.content.truncate(100) : '',
      user: format_user_data(content.user),
      created_at: content.created_at,
      hidden: content.respond_to?(:hidden?) ? content.hidden? : false
    }
  end

  # 生成查询摘要
  def generate_query_summary
    base_query = ContentReport.all
    apply_filters_to_summary_query(base_query)

    {
      total_reports: base_query.count,
      pending_reports: base_query.where(status: :pending).count,
      processed_reports: base_query.where.not(status: :pending).count,
      by_status: base_query.group(:status).count,
      by_reason: base_query.group(:reason).count
    }
  end

  # 对摘要查询应用过滤器
  def apply_filters_to_summary_query(query)
    # 这里复制上面的过滤器逻辑，但不需要分页和排序
    if filters[:status].present?
      query = query.where(status: filters[:status])
    end

    if filters[:reason].present?
      query = query.where(reason: filters[:reason])
    end

    if filters[:user_id].present?
      query = query.where(user_id: filters[:user_id])
    end

    query
  end

  # 获取被举报的内容数据
  def get_reported_content_data
    # 这是一个特殊查询，直接返回被举报的内容
    query = ContentReport.joins(:target_content)
                         .includes(:target_content, :user)
                         .distinct

    if filters[:status].present?
      query = query.where(content_reports: { status: filters[:status] })
    end

    contents = query.order('content_reports.created_at DESC')
                     .limit(filters[:limit] || 50)

    {
      reported_contents: contents.map do |report|
        {
          content: format_target_content(report.target_content),
          reports_count: report.target_content.content_reports.count,
          latest_report: format_single_report(report)
        }
      end
    }
  end
end