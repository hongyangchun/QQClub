# 通知服务
# 负责管理系统中各种用户通知的创建、发送和管理
class NotificationService < ApplicationService
  include ServiceInterface
  attr_reader :recipient, :actor, :notifiable, :notification_type, :title, :content

  def initialize(recipient:, actor:, notifiable:, notification_type:, title:, content:)
    super()
    @recipient = recipient
    @actor = actor
    @notifiable = notifiable
    @notification_type = notification_type
    @title = title
    @content = content
  end

  def call
    handle_errors do
      validate_parameters
      create_notification
      log_notification_created
      self
    end
  end

  # 类方法：小红花相关通知
  class << self
    # 发送小红花通知
    def send_flower_notification(recipient, actor, flower)
      return false if should_skip_notification?(recipient, actor, Notification::NOTIFICATION_TYPES[:flower_received])

      notification = Notification.create_flower_notification(recipient, actor, flower)
      log_notification("小红花通知", notification)
      notification
    end

    # 发送评论通知
    def send_comment_notification(recipient, actor, comment)
      return false if should_skip_notification?(recipient, actor, Notification::NOTIFICATION_TYPES[:flower_comment])

      notification = Notification.create_comment_notification(recipient, actor, comment)
      log_notification("评论通知", notification)
      notification
    end

    # 发送活动更新通知
    def send_activity_update_notification(recipient, actor, event, update_type, message)
      return false if should_skip_notification?(recipient, actor, Notification::NOTIFICATION_TYPES[:activity_update])

      notification = Notification.create_activity_notification(recipient, actor, event, update_type, message)
      log_notification("活动更新通知", notification)
      notification
    end

    # 发送活动审批通知
    def send_event_approval_notification(recipient, actor, event, approved)
      notification_type = approved ? Notification::NOTIFICATION_TYPES[:event_approved] : Notification::NOTIFICATION_TYPES[:event_rejected]
      return false if should_skip_notification?(recipient, actor, notification_type)

      notification = Notification.create_event_approval_notification(recipient, actor, event, approved)
      log_notification("活动审批通知", notification)
      notification
    end

    # 批量发送通知
    def send_bulk_notifications(recipients, actor, notifiable, notification_type, title, content)
      return [] if recipients.blank?

      notifications = []
      recipients.each do |recipient|
        next if should_skip_notification?(recipient, actor, notification_type)

        notification = Notification.create!(
          recipient: recipient,
          actor: actor,
          notifiable: notifiable,
          notification_type: notification_type,
          title: title,
          content: content
        )
        notifications << notification
      end

      log_bulk_notification(notification_type, notifications.count)
      notifications
    end

    # 发送系统通知
    def send_system_notification(recipients, title, content, options = {})
      actor = options[:actor] || User.find_by(role: 2) # root admin or default actor
      notifiable = options[:notifiable]

      notifications = []
      Array(recipients).each do |recipient|
        notification = Notification.create!(
          recipient: recipient,
          actor: actor,
          notifiable: notifiable || recipient, # 如果没有指定notifiable，使用recipient作为默认值
          notification_type: 'activity_update',
          title: title,
          content: content
        )
        notifications << notification
      end

      log_notification("系统通知", notifications)
      notifications
    end

    # 获取用户未读通知数量
    def unread_count_for(user)
      Notification.unread_count_for(user)
    end

    # 获取用户最近的通知
    def recent_notifications_for(user, limit = 10, include_read: false)
      scope = Notification.for_recipient(user).recent.limit(limit)
      scope = scope.unread unless include_read
      scope
    end

    # 标记通知为已读
    def mark_as_read(notification_id, user)
      notification = Notification.find_by(id: notification_id, recipient: user)
      return false unless notification

      notification.mark_as_read!
      true
    end

    # 批量标记为已读
    def mark_all_as_read_for(user)
      Notification.mark_all_as_read_for(user)
      log_notification_action("批量标记已读", user: user.id)
    end

    # 删除通知
    def delete_notification(notification_id, user)
      notification = Notification.find_by(id: notification_id, recipient: user)
      return false unless notification

      notification.destroy
      log_notification_action("删除通知", user: user.id, notification: notification_id)
      true
    end

    # 批量删除通知
    def delete_notifications(notification_ids, user)
      notifications = Notification.where(id: notification_ids, recipient: user)
      deleted_count = notifications.count
      notifications.destroy_all

      log_notification_action("批量删除通知", user: user.id, count: deleted_count)
      deleted_count
    end

    # 清理过期通知
    def cleanup_old_notifications(days = 30)
      deleted_count = Notification.cleanup_old_notifications(days)
      log_notification_action("清理过期通知", days: days, count: deleted_count)
      deleted_count
    end

    # 获取通知统计
    def notification_stats_for(user, days = 7)
      notifications = Notification.for_recipient(user)
                                 .where('created_at >= ?', days.days.ago)

      {
        total_count: notifications.count,
        unread_count: notifications.unread.count,
        by_type: notifications.group(:notification_type).count,
        recent_count: notifications.where('created_at >= ?', 1.day.ago).count
      }
    end

    # 检查用户是否有新通知
    def has_new_notifications?(user, since: nil)
      scope = Notification.for_recipient(user).unread
      scope = scope.where('created_at > ?', since) if since
      scope.exists?
    end

    # 获取用户的通知偏好设置（预留接口）
    def notification_preferences(user)
      # TODO: 实现用户通知偏好设置
      {
        flower_received: true,
        flower_comment: true,
        activity_update: true,
        event_approved: true,
        event_rejected: true
      }
    end

    # 检查用户是否接收某种类型的通知
    def should_receive_notification?(user, notification_type)
      preferences = notification_preferences(user)
      preferences[notification_type.to_sym]
    end

    private

    # 判断是否应该跳过通知发送
    def should_skip_notification?(recipient, actor, notification_type = nil)
      return true if recipient.nil? || actor.nil?
      return true if recipient.id == actor.id # 不给自己发通知
      return true unless notification_type && should_receive_notification?(recipient, notification_type)
      false
    end

    # 记录通知日志
    def log_notification(type, notification)
      if notification.is_a?(Array)
        Rails.logger.info "批量通知创建成功: #{type} - 数量: #{notification.count}"
      else
        Rails.logger.info "通知创建成功: #{type} - 接收者: #{notification.recipient&.id}, 类型: #{notification.notification_type}"
      end
    end

    # 记录批量通知日志
    def log_bulk_notification(type, count)
      Rails.logger.info "批量通知创建成功: #{type} - 数量: #{count}"
    end

    # 记录通知操作日志
    def log_notification_action(action, **params)
      Rails.logger.info "通知操作: #{action} - #{params}"
    end
  end

  private

  # 验证参数
  def validate_parameters
    errors.add(:recipient, "接收者不能为空") if recipient.blank?
    errors.add(:actor, "发送者不能为空") if actor.blank?
    errors.add(:notification_type, "通知类型不能为空") if notification_type.blank?
    errors.add(:title, "标题不能为空") if title.blank?
    errors.add(:content, "内容不能为空") if content.blank?

    # 验证通知类型
    unless Notification::NOTIFICATION_TYPES.values.include?(notification_type)
      errors.add(:notification_type, "无效的通知类型")
    end

    # 验证接收者和发送者不是同一人
    if recipient.present? && actor.present? && recipient.id == actor.id
      errors.add(:base, "不能给自己发送通知")
    end
  end

  # 创建通知
  def create_notification
    @notification = Notification.create!(
      recipient: recipient,
      actor: actor,
      notifiable: notifiable,
      notification_type: notification_type,
      title: title,
      content: content
    )
  end

  # 记录通知创建日志
  def log_notification_created
    Rails.logger.info "通知创建成功: 类型: #{notification_type}, 接收者: #{recipient.id}, 发送者: #{actor.id}"
  end
end