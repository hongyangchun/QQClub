# frozen_string_literal: true

# ContentModerationService - 内容审核服务（重构版）
# 作为内容审核相关服务的协调器，提供统一的接口
class ContentModerationService < ApplicationService
  attr_reader :action, :params, :current_user

  def initialize(action:, params: {}, current_user: nil)
    super()
    @action = action
    @params = params.with_indifferent_access
    @current_user = current_user
  end

  # 主要调用方法
  def call
    handle_errors do
      validate_action
      execute_action
    end
    self
  end

  # 类方法：创建举报
  def self.create_report(user, target_content, reason:, description: nil)
    new(
      action: :create_report,
      params: {
        user: user,
        target_content: target_content,
        reason: reason,
        description: description
      }
    ).call
  end

  # 类方法：批量处理举报
  def self.batch_process_reports(admin, report_ids, action:, notes: nil)
    new(
      action: :batch_process,
      params: {
        admin: admin,
        report_ids: report_ids,
        action: action,
        notes: notes
      }
    ).call
  end

  # 类方法：获取举报统计
  def self.get_statistics(days = 30)
    new(
      action: :get_statistics,
      params: { days: days }
    ).call
  end

  # 类方法：获取待处理的举报
  def self.get_pending_reports(limit: 50, current_user: nil)
    new(
      action: :get_pending_reports,
      params: { limit: limit },
      current_user: current_user
    ).call
  end

  # 类方法：获取高优先级举报
  def self.get_high_priority_reports(current_user: nil)
    new(
      action: :get_high_priority_reports,
      current_user: current_user
    ).call
  end

  # 类方法：生成审核报告
  def self.generate_moderation_report(start_date = nil, end_date = nil)
    new(
      action: :generate_report,
      params: {
        start_date: start_date,
        end_date: end_date
      }
    ).call
  end

  # 类方法：获取用户举报历史
  def self.get_user_report_history(user, limit: 20, current_user: nil)
    new(
      action: :get_user_history,
      params: {
        user: user,
        limit: limit
      },
      current_user: current_user
    ).call
  end

  # 类方法：获取被举报的内容
  def self.get_reported_content(limit: 50, status: nil, current_user: nil)
    new(
      action: :get_reported_content,
      params: {
        limit: limit,
        status: status
      },
      current_user: current_user
    ).call
  end

  # 类方法：检查内容是否需要自动审核
  def self.check_content_for_review(content)
    new(
      action: :check_content,
      params: { content: content }
    ).call
  end

  # 类方法：搜索举报
  def self.search_reports(query, current_user: nil)
    ContentModerationQueryService.search_reports(query, current_user: current_user)
  end

  private

  # 验证操作
  def validate_action
    valid_actions = [
      :create_report, :batch_process, :get_statistics, :get_pending_reports,
      :get_high_priority_reports, :generate_report, :get_user_history,
      :get_reported_content, :check_content
    ]

    unless valid_actions.include?(action)
      failure!("不支持的操作: #{action}")
      return false
    end

    true
  end

  # 执行具体操作
  def execute_action
    result = case action
             when :create_report
               create_report_action
             when :batch_process
               batch_process_action
             when :get_statistics
               get_statistics_action
             when :get_pending_reports
               get_pending_reports_action
             when :get_high_priority_reports
               get_high_priority_reports_action
             when :generate_report
               generate_report_action
             when :get_user_history
               get_user_history_action
             when :get_reported_content
               get_reported_content_action
             when :check_content
               check_content_action
             end

    if result&.success?
      success!(result.data)
    else
      failure!(result&.error_messages || ["操作失败"])
    end
  end

  # 创建举报操作
  def create_report_action
    ReportCreationService.new(
      user: params[:user],
      target_content: params[:target_content],
      reason: params[:reason],
      description: params[:description]
    ).call
  end

  # 批量处理操作
  def batch_process_action
    ReportProcessingService.new(
      admin: params[:admin],
      report_ids: params[:report_ids],
      action: params[:action],
      notes: params[:notes]
    ).call
  end

  # 获取统计操作
  def get_statistics_action
    days = params[:days] || 30
    service = ContentModerationAnalyticsService.new(
      start_date: days.days.ago.to_date,
      end_date: Date.current
    )
    service.call
    service
  end

  # 获取待处理举报操作
  def get_pending_reports_action
    limit = params[:limit] || 50
    ContentModerationQueryService.get_pending_reports(
      limit: limit,
      current_user: current_user
    )
  end

  # 获取高优先级举报操作
  def get_high_priority_reports_action
    ContentModerationQueryService.get_high_priority_reports(
      current_user: current_user
    )
  end

  # 生成报告操作
  def generate_report_action
    ContentModerationAnalyticsService.generate_moderation_report(
      params[:start_date],
      params[:end_date]
    )
  end

  # 获取用户历史操作
  def get_user_history_action
    limit = params[:limit] || 20
    ContentModerationQueryService.get_user_report_history(
      params[:user],
      limit: limit,
      current_user: current_user
    )
  end

  # 获取被举报内容操作
  def get_reported_content_action
    ContentModerationQueryService.get_reported_content(
      limit: params[:limit],
      status: params[:status],
      current_user: current_user
    )
  end

  # 检查内容操作
  def check_content_action
    content = params[:content]
    return failure!("内容不能为空") unless content

    # 这里应该调用内容检查服务
    # 为了简化，返回一个基本的检查结果
    {
      needs_review: false,
      priority: 'low',
      issues: []
    }
  end
end