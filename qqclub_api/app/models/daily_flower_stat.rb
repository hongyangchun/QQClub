class DailyFlowerStat < ApplicationRecord
  # 关联
  belongs_to :reading_event

  # 验证
  validates :reading_event_id, :stats_date, :leaderboard_data, :generated_at, presence: true
  validates :stats_date, uniqueness: { scope: :reading_event_id }

  # 作用域
  scope :for_event, ->(event) { where(reading_event: event) }
  scope :for_date, ->(date) { where(stats_date: date) }
  scope :recent_first, -> { order(generated_at: :desc) }
  scope :generated_between, ->(start_date, end_date) { where(generated_at: start_date..end_date) }

  # 回调
  before_validation :set_generated_at, on: :create

  # 实例方法

  # 获取排行榜数据（解析JSON）
  def leaderboard
    return [] unless leaderboard_data.is_a?(Hash)

    leaderboard_data['rankings'] || []
  end

  # 获取前三名
  def top_three
    leaderboard.first(3)
  end

  # 获取指定用户的排名
  def user_ranking(user)
    return nil unless user

    leaderboard.find { |entry| entry['user_id'] == user.id }
  end

  # 获取分享文案
  def share_text_for_wechat
    return share_text if share_text.present?

    default_text = "🌸 #{reading_event.title} #{stats_date.strftime('%m月%d日')}小红花排行榜\n\n"
    default_text += "🏆 今日小红花TOP3：\n"

    top_three.each_with_index do |entry, index|
      user = User.find_by(id: entry['user_id'])
      next unless user

      emoji = ['🥇', '🥈', '🥉'][index]
      default_text += "#{emoji} #{user.nickname} - #{entry['total_flowers']}朵\n"
    end

    default_text += "\n💝 总计#{total_flowers_given}朵小红花，#{total_participants}位小伙伴参与"
    default_text
  end

  # 检查是否为今日统计
  def for_today?
    stats_date == Date.current
  end

  # 检查是否为昨日统计
  def for_yesterday?
    stats_date == Date.yesterday
  end

  # 增加分享次数
  def increment_share_count!
    increment!(:share_count)
  end

  # 生成分享图片URL（占位符，实际实现需要集成图片生成服务）
  def generate_share_image_url
    # 这里可以集成第三方图片生成服务，如：
    # - 使用Canvas API生成图片
    # - 使用微信小程序生成分享图片
    # - 使用第三方API服务

    timestamp = generated_at.to_i
    "https://api.example.com/share-images/daily-flower-stats/#{id}?t=#{timestamp}"
  end

  # API响应格式
  def as_json_for_api
    {
      id: id,
      reading_event: reading_event.as_json_for_api,
      stats_date: stats_date,
      leaderboard: leaderboard,
      top_three: top_three.map do |entry|
        user = User.find_by(id: entry['user_id'])
        {
          rank: entry['rank'],
          user: user&.as_json_for_api,
          total_flowers: entry['total_flowers'],
          flowers_received: entry['flowers_received'],
          flowers_given: entry['flowers_given']
        }
      end,
      statistics: {
        total_flowers_given: total_flowers_given,
        total_participants: total_participants,
        total_givers: total_givers,
        share_count: share_count
      },
      share_info: {
        image_url: share_image_url || generate_share_image_url,
        text: share_text_for_wechat,
        share_count: share_count
      },
      generated_at: generated_at,
      for_today: for_today?,
      for_yesterday: for_yesterday?
    }
  end

  # 类方法

  # 获取或创建指定日期的统计
  def self.get_or_create_daily_stat(event, date = Date.yesterday)
    find_or_create_by(reading_event: event, stats_date: date) do |stat|
      stat.generated_at = Time.current
      stat.generated_by = 'system_auto'
    end
  end

  # 检查是否已存在指定日期的统计
  def self.exists_for_date?(event, date)
    exists_by?(reading_event: event, stats_date: date)
  end

  # 获取活动的统计历史
  def self.event_statistics_history(event, limit: 30)
    for_event(event)
      .recent_first
      .limit(limit)
  end

  # 获取最近N天的统计
  def self.recent_statistics(days = 7)
    where(stats_date: (Date.current - days.days)..Date.current)
      .order(stats_date: :desc)
  end

  private

  def set_generated_at
    self.generated_at ||= Time.current
    self.generated_by ||= 'system_auto'
  end
end