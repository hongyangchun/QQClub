# 通知模型
# 用于管理系统中各种用户通知，包括小红花相关通知、评论通知、活动通知等
class Notification < ApplicationRecord
  # 关联关系
  belongs_to :recipient, class_name: 'User'
  belongs_to :actor, class_name: 'User'
  belongs_to :notifiable, polymorphic: true

  # 验证规则
  validates :recipient, presence: true
  validates :actor, presence: true
  validates :notification_type, presence: true, inclusion: { in: %w[flower_received flower_comment activity_update event_approved event_rejected] }
  validates :title, presence: true, length: { maximum: 100 }
  validates :content, presence: true, length: { maximum: 500 }

  # 作用域
  scope :unread, -> { where(read: false) }
  scope :read, -> { where(read: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_type, ->(type) { where(notification_type: type) }
  scope :for_recipient, ->(user) { where(recipient: user) }

  # 通知类型常量
  NOTIFICATION_TYPES = {
    flower_received: 'flower_received',           # 收到小红花
    flower_comment: 'flower_comment',             # 小红花被评论
    activity_update: 'activity_update',           # 活动更新
    event_approved: 'event_approved',             # 活动审批通过
    event_rejected: 'event_rejected'              # 活动审批拒绝
  }.freeze

  # 默认排序
  default_scope -> { order(created_at: :desc) }

  # 实例方法

  # 标记为已读
  def mark_as_read!
    update!(read: true, read_at: Time.current) unless read?
  end

  # 标记为未读
  def mark_as_unread!
    update!(read: false, read_at: nil)
  end

  # 是否已读
  def read?
    read
  end

  # 是否未读
  def unread?
    !read
  end

  # 获取通知的URL链接
  def action_url
    case notification_type
    when 'flower_received', 'flower_comment'
      if notifiable_type == 'Flower'
        "/flowers/#{notifiable_id}"
      elsif notifiable_type == 'Comment'
        comment = Comment.find_by(id: notifiable_id)
        if comment&.commentable_type == 'Flower'
          "/flowers/#{comment.commentable_id}#comment-#{comment.id}"
        end
      end
    when 'activity_update', 'event_approved', 'event_rejected'
      if notifiable_type == 'ReadingEvent'
        "/events/#{notifiable_id}"
      end
    else
      '#'
    end
  end

  # 获取通知图标类型
  def icon_type
    case notification_type
    when 'flower_received'
      'flower'
    when 'flower_comment'
      'comment'
    when 'activity_update'
      'activity'
    when 'event_approved'
      'approved'
    when 'event_rejected'
      'rejected'
    else
      'notification'
    end
  end

  # 格式化创建时间
  def formatted_created_at
    case Time.current - created_at
    when 0..59.seconds
      '刚刚'
    when 1..59.minutes
      "#{(Time.current - created_at).to_i / 60}分钟前"
    when 1..23.hours
      "#{(Time.current - created_at).to_i / 3600}小时前"
    when 1..29.days
      "#{(Time.current - created_at).to_i / 86400}天前"
    else
      created_at.strftime('%m-%d %H:%M')
    end
  end

  # API响应格式
  def as_json_for_api(options = {})
    base_data = {
      id: id,
      notification_type: notification_type,
      title: title,
      content: content,
      read: read,
      read_at: read_at,
      created_at: created_at,
      formatted_created_at: formatted_created_at,
      action_url: action_url,
      icon_type: icon_type
    }

    # 包含关联数据
    if options[:include_actor]
      base_data[:actor] = actor.as_json_for_api
    end

    if options[:include_notifiable]
      base_data[:notifiable] = if notifiable
        {
          type: notifiable_type,
          id: notifiable_id,
          data: notifiable.as_json_for_api
        }
      else
        nil
      end
    end

    base_data
  end

  # 类方法

  # 创建小红花通知
  def self.create_flower_notification(recipient, actor, flower)
    create!(
      recipient: recipient,
      actor: actor,
      notifiable: flower,
      notification_type: NOTIFICATION_TYPES[:flower_received],
      title: '收到小红花',
      content: "#{actor.nickname} 给了你一朵小红花：#{flower.comment.presence || '很棒的表现！'}"
    )
  end

  # 创建评论通知
  def self.create_comment_notification(recipient, actor, comment)
    create!(
      recipient: recipient,
      actor: actor,
      notifiable: comment,
      notification_type: NOTIFICATION_TYPES[:flower_comment],
      title: '新的评论',
      content: "#{actor.nickname} 评论了你的小红花：#{comment.content.truncate(50)}"
    )
  end

  # 创建活动更新通知
  def self.create_activity_notification(recipient, actor, event, update_type, message)
    create!(
      recipient: recipient,
      actor: actor,
      notifiable: event,
      notification_type: NOTIFICATION_TYPES[:activity_update],
      title: '活动更新',
      content: message
    )
  end

  # 创建活动审批通知
  def self.create_event_approval_notification(recipient, actor, event, approved)
    notification_type = approved ? NOTIFICATION_TYPES[:event_approved] : NOTIFICATION_TYPES[:event_rejected]
    title = approved ? '活动审批通过' : '活动审批拒绝'

    create!(
      recipient: recipient,
      actor: actor,
      notifiable: event,
      notification_type: notification_type,
      title: title,
      content: "#{actor.nickname} #{approved ? '通过了' : '拒绝了'}你的活动申请：#{event.title}"
    )
  end

  # 批量标记为已读
  def self.mark_all_as_read_for(recipient)
    where(recipient: recipient, read: false).update_all(read: true, read_at: Time.current)
  end

  # 获取用户未读通知数量
  def self.unread_count_for(recipient)
    where(recipient: recipient, read: false).count
  end

  # 获取用户最近的通知
  def self.recent_for(recipient, limit = 10)
    where(recipient: recipient).limit(limit)
  end

  # 清理过期通知（保留30天）
  def self.cleanup_old_notifications(days = 30)
    where('created_at < ?', days.days.ago).delete_all
  end
end
