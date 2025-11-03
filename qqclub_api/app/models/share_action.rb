class ShareAction < ApplicationRecord
  # 关联
  belongs_to :user, optional: true

  # 验证
  validates :share_type, :resource_id, :platform, presence: true

  # 枚举
  enum :share_type, {
    daily_leaderboard: 'daily_leaderboard',    # 每日排行榜
    final_leaderboard: 'final_leaderboard',    # 最终排行榜
    certificate: 'certificate',                # 证书分享
    user_achievement: 'user_achievement'       # 用户成就
  }

  enum :platform, {
    wechat: 'wechat',        # 微信
    weibo: 'weibo',          # 微博
    qq: 'qq',                # QQ
    copy_link: 'copy_link'   # 复制链接
  }

  # 作用域
  scope :for_share_type, ->(type) { where(share_type: type) }
  scope :for_platform, ->(platform) { where(platform: platform) }
  scope :for_user, ->(user) { where(user: user) }
  scope :recent, -> { order(shared_at: :desc) }
  scope :today, -> { where(shared_at: Date.current.beginning_of_day..Date.current.end_of_day) }

  # 回调
  before_validation :set_shared_at, on: :create

  # 实例方法

  # 获取分享的资源对象
  def resource
    case share_type
    when 'daily_leaderboard'
      DailyFlowerStat.find_by(id: resource_id)
    when 'final_leaderboard'
      FlowerCertificate.for_event(ReadingEvent.find_by(id: resource_id))
    when 'certificate'
      FlowerCertificate.find_by(certificate_id: resource_id)
    when 'user_achievement'
      { user_id: user_id, event_id: resource_id }
    end
  end

  # 获取分享的显示名称
  def share_type_display
    case share_type
    when 'daily_leaderboard'
      '每日排行榜'
    when 'final_leaderboard'
      '最终排行榜'
    when 'certificate'
      '证书分享'
    when 'user_achievement'
      '个人成就'
    else
      share_type
    end
  end

  # 获取平台显示名称
  def platform_display
    case platform
    when 'wechat'
      '微信'
    when 'weibo'
      '微博'
    when 'qq'
      'QQ'
    when 'copy_link'
      '复制链接'
    else
      platform
    end
  end

  # 检查是否为今日分享
  def shared_today?
    shared_at.to_date == Date.current
  end

  # API响应格式
  def as_json_for_api
    {
      id: id,
      share_type: share_type_display,
      platform: platform_display,
      resource_id: resource_id,
      user: user&.as_json_for_api,
      shared_at: shared_at,
      shared_today: shared_today?,
      ip_address: ip_address
    }
  end

  # 类方法

  # 获取分享统计
  def self.share_statistics(days: 7)
    start_date = days.days.ago.to_date

    stats = where('shared_at >= ?', start_date)
          .group(:share_type, :platform)
          .count

    {
      period: "#{start_date} 至 #{Date.current}",
      total_shares: stats.values.sum,
      share_type_breakdown: stats.group_by { |(type, _), _| type }
                                .transform_values { |items| items.values.sum },
      platform_breakdown: stats.group_by { |(_, platform), _| platform }
                                .transform_values(&:sum),
      detailed_stats: stats
    }
  end

  # 获取用户的分享历史
  def self.user_share_history(user, limit: 20)
    for_user(user)
      .recent
      .limit(limit)
      .includes(:user)
  end

  # 获取热门分享内容
  def self.popular_shares(days: 7, limit: 10)
    start_date = days.days.ago.to_date

    joins(:user)
      .where('shared_at >= ?', start_date)
      .group(:share_type, :resource_id)
      .order('COUNT(*) DESC')
      .limit(limit)
      .count
  end

  # 记录分享行为（便捷方法）
  def self.record_share(share_type:, resource_id:, platform:, user: nil, ip_address: nil, user_agent: nil)
    create!(
      share_type: share_type,
      resource_id: resource_id,
      platform: platform,
      user: user,
      ip_address: ip_address,
      user_agent: user_agent,
      shared_at: Time.current
    )
  rescue => e
    Rails.logger.error "记录分享行为失败: #{e.message}"
    nil
  end

  private

  def set_shared_at
    self.shared_at ||= Time.current
  end
end