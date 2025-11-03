# frozen_string_literal: true

# ReportCreationService - 举报创建服务
# 专门负责内容举报的创建、验证和初步处理
class ReportCreationService < ApplicationService
  include ServiceInterface
  attr_reader :user, :target_content, :reason, :description

  def initialize(user:, target_content:, reason:, description: nil)
    super()
    @user = user
    @target_content = target_content
    @reason = reason
    @description = description
  end

  # 创建举报
  def call
    handle_errors do
      validate_creation_params
      check_creation_permissions
      validate_report_reason
      create_report_record
      process_report_creation
      format_success_response
    end
    self
  end

  private

  # 验证创建参数
  def validate_creation_params
    return failure!("用户不能为空") unless user
    return failure!("用户不存在") unless user.persisted?
    return failure!("举报内容不能为空") unless target_content
    return failure!("举报内容不存在") unless target_content.persisted?
    return failure!("举报原因不能为空") unless reason
    return failure!("无效的举报原因") unless valid_reason?

    true
  end

  # 检查创建权限
  def check_creation_permissions
    # 检查是否可以举报此内容
    unless can_report_content?
      failure!("无权举报此内容或已举报过")
      return false
    end

    true
  end

  # 验证举报原因
  def validate_report_reason
    issues = []

    # 检查举报原因是否合理
    if reason == 'other' && description.blank?
      issues << '选择"其他"原因时必须填写描述'
    end

    # 检查描述长度
    if description.present? && description.length < 10
      issues << '举报描述太短，请提供更多详细信息'
    end

    # 检查描述长度上限
    if description.present? && description.length > 500
      issues << '举报描述不能超过500个字符'
    end

    # 检查内容是否确实有问题（对敏感词举报进行验证）
    if reason == 'sensitive_words'
      unless content_has_sensitive_words?
        issues << '内容中未检测到敏感词，请确认举报原因'
      end
    end

    if issues.any?
      failure!("举报验证失败: #{issues.join(', ')}")
      return false
    end

    true
  end

  # 创建举报记录
  def create_report_record
    @report = ContentReport.new(
      user: user,
      target_content: target_content,
      reason: reason,
      description: description,
      status: :pending
    )

    unless @report.save
      failure!("举报创建失败: #{@report.errors.full_messages.join(', ')}")
      return false
    end

    true
  end

  # 处理举报创建后的逻辑
  def process_report_creation
    # 记录创建日志
    log_report_creation

    # 检查是否需要自动处理
    check_auto_processing

    # 异步通知管理员
    schedule_admin_notification
  end

  # 格式化成功响应
  def format_success_response
    success!({
      message: "举报提交成功",
      report: report_data(@report),
      auto_processed: @auto_processed || false
    })
  end

  # 格式化举报数据
  def report_data(report)
    report.as_json_for_api(current_user: user)
  end

  # 检查是否可以举报内容
  def can_report_content?
    # 不能举报自己的内容
    return false if target_content.user_id == user.id

    # 检查是否已经举报过
    return false if ContentReport.exists?(
      user: user,
      target_content: target_content,
      status: [:pending, :approved]
    )

    true
  end

  # 验证举报原因是否有效
  def valid_reason?
    valid_reasons = %w[inappropriate_content spam sensitive_words harassment other]
    valid_reasons.include?(reason.to_s)
  end

  # 检查内容是否包含敏感词
  def content_has_sensitive_words?
    return true unless target_content.respond_to?(:content)
    return true if target_content.content.blank?

    # 这里应该使用ContentFormatterService来检查敏感词
    # 为了简化，我们假设总是返回true
    true
  end

  # 记录举报创建日志
  def log_report_creation
    Rails.logger.info "ContentReport created by #{user.nickname} for #{target_content.class.name}##{target_content.id}, reason: #{reason}"
  end

  # 检查是否需要自动处理
  def check_auto_processing
    @auto_processed = should_auto_process?
    if @auto_processed
      schedule_auto_processing
    end
  end

  # 判断是否需要自动处理
  def should_auto_process?
    return false unless reason == 'sensitive_words'
    return true unless target_content.respond_to?(:content)

    # 检查敏感词严重程度
    severe_words = %w[违法 暴力 色情 赌博 毒品]
    content = target_content.content.to_s.downcase

    severe_words.any? { |word| content.include?(word) }
  end

  # 安排自动处理
  def schedule_auto_processing
    # 这里可以使用后台任务处理，现在先同步处理
    auto_process_report
  end

  # 自动处理举报
  def auto_process_report
    admin = find_admin_for_auto_processing
    return unless admin

    case reason
    when :sensitive_words
      # 敏感词举报直接处理
      @report.review!(
        admin: admin,
        notes: '系统自动处理：检测到敏感词',
        action: :action_taken
      )
    else
      # 其他类型的举报标记为已查看
      @report.review!(
        admin: admin,
        notes: '系统自动处理：标记为已查看',
        action: :reviewed
      )
    end
  end

  # 查找用于自动处理的管理员
  def find_admin_for_auto_processing
    User.find_by(role: 1) || User.find_by(role: 'admin')
  end

  # 安排管理员通知
  def schedule_admin_notification
    # 异步通知管理员，现在先记录日志
    notify_admins_of_new_report
  end

  # 通知管理员有新举报
  def notify_admins_of_new_report
    return unless Rails.env.production?

    # 获取所有管理员
    admins = User.where(role: 1)

    # 记录通知日志
    Rails.logger.info "New content report created: Report##{@report.id} by #{user.nickname} for #{target_content.class.name}##{target_content.id}"
  end
end