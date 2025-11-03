# frozen_string_literal: true

# ReportProcessingService - 举报处理服务
# 专门负责举报的审核、处理和批量操作
class ReportProcessingService < ApplicationService
  include ServiceInterface
  attr_reader :admin, :report_ids, :action, :notes

  def initialize(admin:, report_ids:, action:, notes: nil)
    super()
    @admin = admin
    @report_ids = Array(report_ids)
    @action = action
    @notes = notes
  end

  # 批量处理举报
  def call
    handle_errors do
      validate_processing_params
      check_processing_permissions
      find_reports
      process_reports
      log_processing_results
      schedule_notifications
      format_success_response
    end
    self
  end

  # 单个举报处理
  def self.process_single_report(admin, report, action:, notes: nil)
    new(
      admin: admin,
      report_ids: [report.id],
      action: action,
      notes: notes
    ).call
  end

  private

  # 验证处理参数
  def validate_processing_params
    return failure!("管理员不能为空") unless admin
    return failure!("管理员不存在") unless admin.persisted?
    return failure!("举报ID不能为空") if report_ids.empty?
    return failure!("处理动作不能为空") unless action
    return failure!("无效的处理动作") unless valid_action?

    true
  end

  # 检查处理权限
  def check_processing_permissions
    unless admin.can_approve_events?
      failure!("无权限执行此操作")
      return false
    end

    true
  end

  # 验证处理动作是否有效
  def valid_action?
    valid_actions = %w[approve reject reviewed action_taken]
    valid_actions.include?(action.to_s)
  end

  # 查找待处理的举报
  def find_reports
    @reports = ContentReport.where(id: report_ids, status: :pending)

    if @reports.empty?
      failure!("没有找到待处理的举报")
      return false
    end

    # 检查是否有举报不存在或已处理
    found_ids = @reports.pluck(:id)
    missing_ids = report_ids - found_ids

    if missing_ids.any?
      Rails.logger.warn "Some report IDs not found or already processed: #{missing_ids}"
    end

    true
  end

  # 处理举报
  def process_reports
    @results = []
    @processed_count = 0
    @failed_count = 0

    @reports.each do |report|
      result = process_single_report(report)

      @results << {
        report_id: report.id,
        success: result[:success],
        error: result[:error]
      }

      if result[:success]
        @processed_count += 1
      else
        @failed_count += 1
      end
    end

    true
  end

  # 处理单个举报
  def process_single_report(report)
    begin
      # 执行举报审核
      success = report.review!(
        admin: admin,
        notes: notes,
        action: action.to_sym
      )

      # 根据处理结果执行后续操作
      if success && should_take_action_on_content?(report)
        process_reported_content(report)
      end

      {
        success: true,
        report: report
      }
    rescue => e
      Rails.logger.error "Failed to process report #{report.id}: #{e.message}"
      {
        success: false,
        error: e.message
      }
    end
  end

  # 判断是否需要对被举报内容执行操作
  def should_take_action_on_content?(report)
    action == 'action_taken' && report.status == 'approved'
  end

  # 处理被举报的内容
  def process_reported_content(report)
    target_content = report.target_content
    return unless target_content

    case report.reason
    when 'inappropriate_content', 'sensitive_words'
      # 隐藏不当内容
      hide_content(target_content, report)
    when 'spam'
      # 标记为垃圾内容
      mark_as_spam(target_content, report)
    when 'harassment'
      # 隐藏骚扰内容并可能对用户进行处罚
      handle_harassment_content(target_content, report)
    end
  end

  # 隐藏内容
  def hide_content(content, report)
    if content.respond_to?(:hide!)
      content.hide!
      Rails.logger.info "Content #{content.class.name}##{content.id} hidden due to report #{report.id}"
    end
  end

  # 标记为垃圾内容
  def mark_as_spam(content, report)
    if content.respond_to?(:mark_as_spam!)
      content.mark_as_spam!
      Rails.logger.info "Content #{content.class.name}##{content.id} marked as spam due to report #{report.id}"
    end
  end

  # 处理骚扰内容
  def handle_harassment_content(content, report)
    # 隐藏内容
    hide_content(content, report)

    # 记录用户违规行为，可能需要进一步处罚
    record_user_violation(content.user, report)
  end

  # 记录用户违规行为
  def record_user_violation(user, report)
    return unless user

    # 这里可以创建用户违规记录或者更新违规计数
    Rails.logger.info "User #{user.id} recorded for harassment violation via report #{report.id}"
  end

  # 记录处理结果日志
  def log_processing_results
    Rails.logger.info "Report processing completed by #{admin.nickname}: " \
                     "#{@processed_count} processed, #{@failed_count} failed, " \
                     "action: #{action}"
  end

  # 安排通知
  def schedule_notifications
    # 异步通知举报人状态更新
    @reports.each do |report|
      notify_reporter_of_status_change(report)
    end
  end

  # 通知举报人状态更新
  def notify_reporter_of_status_change(report)
    return unless Rails.env.production?

    # 这里可以发送通知给举报人
    Rails.logger.info "ContentReport##{report.id} status updated to #{report.status} by #{admin.nickname}"
  end

  # 格式化成功响应
  def format_success_response
    success!({
      message: "举报处理完成",
      processed_count: @processed_count,
      failed_count: @failed_count,
      total_count: @reports.count,
      results: @results
    })
  end
end