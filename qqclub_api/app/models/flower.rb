class Flower < ApplicationRecord
  # 关联
  belongs_to :check_in
  belongs_to :giver, class_name: "User"
  belongs_to :recipient, class_name: "User"
  belongs_to :reading_schedule
  has_many :comments, as: :commentable, dependent: :destroy

  # 验证
  validates :check_in_id, uniqueness: { message: "该打卡已获得小红花" }
  validate :daily_flower_limit
  validate :giver_is_daily_leader

  # 获取赠送者显示名称
  def giver_display_name
    return '匿名用户' if is_anonymous?
    giver&.nickname || '未知用户'
  end

  # 获取接收者显示名称
  def recipient_display_name
    recipient&.nickname || '未知用户'
  end

  # 评论相关方法
  def add_comment(user, content)
    comments.create!(
      user: user,
      content: content,
      commentable: self
    )
  end

  def can_receive_comment?(user)
    # 小红花接收者可以查看和回复评论
    return true if user.present?
    # 这里可以添加更多权限逻辑
    true
  end

  def recent_comments(limit = 5)
    comments.includes(:user).order(created_at: :desc).limit(limit)
  end

  def comments_count
    comments.count
  end

  # API响应格式
  def as_json_for_api(options = {})
    base_data = {
      id: id,
      giver: is_anonymous? ? { id: nil, nickname: '匿名用户' } : giver.as_json_for_api,
      recipient: recipient.as_json_for_api,
      check_in: {
        id: check_in.id,
        content: check_in.content.truncate(100),
        user: check_in.user.as_json_for_api,
        created_at: check_in.created_at
      },
      amount: amount,
      flower_type: flower_type,
      comment: comment,
      is_anonymous: is_anonymous,
      created_at: created_at,
      giver_display_name: giver_display_name,
      recipient_display_name: recipient_display_name,
      comments_count: comments_count
    }

    # 可选包含评论数据
    if options[:include_comments]
      base_data[:comments] = recent_comments.map(&:as_json_for_api)
    end

    if options[:include_comment_stats]
      base_data[:comment_stats] = {
        total_count: comments_count,
        recent_count: recent_comments.count,
        latest_comment: recent_comments.first&.as_json_for_api
      }
    end

    base_data
  end

  private

  # 每日最多发放3朵小红花
  def daily_flower_limit
    daily_count = Flower.where(
      giver: giver,
      reading_schedule: reading_schedule
    ).count

    if daily_count >= 3 && !persisted?
      errors.add(:base, "每日最多发放3朵小红花")
    end
  end

  # 只有领读人可以发放小红花（考虑3天权限窗口）
  def giver_is_daily_leader
    return if reading_schedule.blank? || giver.blank?

    # 检查是否有权限发放小红花（当天和后一天权限）
    event = reading_schedule.reading_event
    unless event&.can_give_flowers?(giver, reading_schedule)
      errors.add(:base, "只有领读人可以在当天或后一天发放小红花")
    end
  end
end
