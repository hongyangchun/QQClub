# frozen_string_literal: true

# ModerationNotificationService - 内容审核通知服务
# 专门负责内容审核相关的通知管理
class ModerationNotificationService < ApplicationService
  include ServiceInterface
  attr_reader :report, :notification_type, :options

  def initialize(report:, notification_type:, options: {})
    super()
    @report = report
    @notification_type = notification_type
    @options = options.with_indifferent_access
  end

  # 发送通知
  def call
    handle_errors do
      validate_notification_params
      send_notifications
      log_notification_activity
    end
    self
  end

  # 类方法：通知管理员有新举报
  def self.notify_admins_of_new_report(report)
    new(
      report: report,
      notification_type: :new_report
    ).call
  end

  # 类方法：通知举报人状态更新
  def self.notify_reporter_of_status_change(report)
    new(
      report: report,
      notification_type: :status_change
    ).call
  end

  # 类方法：通知内容作者
  def self.notify_content_author(report, action_taken:)
    new(
      report: report,
      notification_type: :content_action,
      options: { action_taken: action_taken }
    ).call
  end

  # 类方法：发送每日审核摘要
  def self.send_daily_summary(date = Date.current)
    reports = ContentReport.where(created_at: date.all_day)

    new(
      report: nil,
      notification_type: :daily_summary,
      options: { date: date, reports: reports }
    ).call
  end

  private

  # 验证通知参数
  def validate_notification_params
    case notification_type
    when :new_report, :status_change, :content_action
      return failure!("举报不能为空") unless report
      return failure!("举报不存在") unless report.persisted?
    when :daily_summary
      # 这些通知类型不需要具体的report实例
    else
      return failure!("无效的通知类型")
    end

    true
  end

  # 发送通知
  def send_notifications
    case notification_type
    when :new_report
      notify_admins_new_report
    when :status_change
      notify_reporter_status_change
    when :content_action
      notify_content_author_action
    when :daily_summary
      send_daily_summary_notifications
    end

    true
  end

  # 通知管理员有新举报
  def notify_admins_new_report
    return unless Rails.env.production? || options[:force_notification]

    admins = get_admin_users
    return if admins.empty?

    admins.each do |admin|
      send_notification_to_admin(admin, :new_report, {
        report_id: report.id,
        reason: report.reason,
        reporter: report.user&.nickname,
        content_preview: get_content_preview
      })
    end
  end

  # 通知举报人状态更新
  def notify_reporter_status_change
    return unless Rails.env.production? || options[:force_notification]
    return unless report.user

    send_notification_to_user(report.user, :report_status_change, {
      report_id: report.id,
      status: report.status,
      admin_notes: report.notes,
      processed_at: report.updated_at
    })
  end

  # 通知内容作者
  def notify_content_author_action
    return unless Rails.env.production? || options[:force_notification]
    return unless report&.target_content&.user

    content_author = report.target_content.user
    return if content_author == report.user # 不通知自己举报自己的情况

    send_notification_to_user(content_author, :content_moderation_action, {
      content_id: report.target_content.id,
      content_type: report.target_content.class.name,
      action_taken: options[:action_taken],
      reason: report.reason,
      moderator: report.admin&.nickname
    })
  end

  # 发送每日审核摘要
  def send_daily_summary_notifications
    return unless Rails.env.production? || options[:force_notification]

    date = options[:date]
    reports = options[:reports]

    return if reports.empty?

    admins = get_admin_users
    return if admins.empty?

    summary_data = generate_daily_summary(date, reports)

    admins.each do |admin|
      send_notification_to_admin(admin, :daily_summary, summary_data)
    end
  end

  # 发送通知给管理员
  def send_notification_to_admin(admin, type, data)
    # 这里可以集成多种通知方式
    send_in_app_notification(admin, type, data)
    send_email_notification(admin, type, data) if should_send_email?(admin, type)
    send_push_notification(admin, type, data) if should_send_push?(admin, type)
  end

  # 发送通知给用户
  def send_notification_to_user(user, type, data)
    # 用户通知主要使用应用内通知
    send_in_app_notification(user, type, data)
    send_email_notification(user, type, data) if should_send_email_to_user?(user, type)
  end

  # 发送应用内通知
  def send_in_app_notification(user, type, data)
    notification_data = build_notification_data(type, data)

    # 这里应该调用通知服务创建应用内通知
    # NotificationService.create_notification(user, notification_data)

    Rails.logger.info "In-app notification created for #{user.nickname}: #{type} - #{notification_data[:title]}"
  end

  # 发送邮件通知
  def send_email_notification(user, type, data)
    return unless user.respond_to?(:email) && user.email.present?

    # 这里应该调用邮件服务发送邮件
    # EmailService.send_moderation_notification(user, type, data)

    Rails.logger.info "Email notification sent to #{user.email}: #{type}"
  end

  # 发送推送通知
  def send_push_notification(user, type, data)
    # 这里应该调用推送服务发送推送
    # PushService.send_notification(user, build_push_data(type, data))

    Rails.logger.info "Push notification sent to #{user.nickname}: #{type}"
  end

  # 构建通知数据
  def build_notification_data(type, data)
    case type
    when :new_report
      {
        title: '新内容举报',
        message: "#{data[:reporter]} 举报了内容：#{data[:reason]}",
        url: "/admin/content_reports/#{data[:report_id]}",
        priority: 'high'
      }
    when :report_status_change
      {
        title: '举报状态更新',
        message: "您的举报已#{data[:status]}，管理员备注：#{data[:admin_notes]}",
        url: "/user/reports/#{data[:report_id]}"
      }
    when :content_moderation_action
      action_text = data[:action_taken] == 'hidden' ? '已被隐藏' : '已被处理'
      {
        title: '内容审核通知',
        message: "您的内容#{action_text}，原因：#{data[:reason]}",
        url: "/user/content/#{data[:content_id]}"
      }
    when :daily_summary
      {
        title: '每日审核摘要',
        message: "昨日共收到#{data[:total_reports]}个举报，已处理#{data[:processed_reports]}个",
        url: "/admin/analytics/content_moderation"
      }
    else
      {
        title: '内容审核通知',
        message: '您有新的内容审核相关信息'
      }
    end
  end

  # 生成每日摘要数据
  def generate_daily_summary(date, reports)
    {
      date: date,
      total_reports: reports.count,
      pending_reports: reports.pending.count,
      processed_reports: reports.where.not(status: :pending).count,
      by_reason: reports.group(:reason).count,
      high_priority_reports: reports.where(reason: %w[sensitive_words harassment]).count
    }
  end

  # 获取管理员用户
  def get_admin_users
    User.where(role: 1).or(User.where(role: 'admin'))
  end

  # 获取内容预览
  def get_content_preview
    return nil unless report&.target_content&.respond_to?(:content)

    content = report.target_content.content
    content ? content.truncate(100) : ''
  end

  # 判断是否应该发送邮件
  def should_send_email?(user, type)
    return false unless user.respond_to?(:email_notifications)
    return false unless user.email_notifications?
    return false unless user.respond_to?(:moderation_email_notifications)

    case type
    when :new_report
      user.moderation_email_notifications?
    when :daily_summary
      user.daily_summary_emails?
    else
      true
    end
  end

  # 判断是否应该向用户发送邮件
  def should_send_email_to_user?(user, type)
    return false unless user.respond_to?(:email_notifications)
    return false unless user.email_notifications?

    case type
    when :report_status_change
      user.report_status_email_notifications?
    else
      true
    end
  end

  # 判断是否应该发送推送通知
  def should_send_push?(user, type)
    return false unless user.respond_to?(:push_notifications)
    return false unless user.push_notifications?

    case type
    when :new_report
      true # 高优先级通知
    when :daily_summary
      false # 摘要通知不需要推送
    else
      user.moderation_push_notifications?
    end
  end

  # 记录通知活动日志
  def log_notification_activity
    case notification_type
    when :new_report
      Rails.logger.info "Admins notified of new content report: Report##{report.id}"
    when :status_change
      Rails.logger.info "Reporter notified of status change: Report##{report.id} -> #{report.status}"
    when :content_action
      Rails.logger.info "Content author notified of moderation action: Report##{report.id}"
    when :daily_summary
      Rails.logger.info "Daily moderation summary sent for #{options[:date]}"
    end
  end
end