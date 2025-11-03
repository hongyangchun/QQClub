class FlowerCertificate < ApplicationRecord
  # 关联
  belongs_to :user
  belongs_to :reading_event

  # 验证
  validates :rank, inclusion: { in: [1, 2, 3] }
  validates :total_flowers, numericality: { greater_than: 0 }
  validates :certificate_id, presence: true, uniqueness: true

  # 作用域
  scope :for_user, ->(user) { where(user: user) }
  scope :for_event, ->(event) { where(reading_event: event) }
  scope :ranked, -> { order(:rank) }

  # 回调
  before_validation :generate_certificate_id, on: :create

  # 实例方法

  # 获取排名显示
  def rank_display
    case rank
    when 1 then '🥇 第一名'
    when 2 then '🥈 第二名'
    when 3 then '🥉 第三名'
    else "第#{rank}名"
    end
  end

  # 获取荣誉等级
  def honor_level
    case rank
    when 1 then '优秀小红花达人'
    when 2 then '小红花之星'
    when 3 then '小红花爱好者'
    else '小红花参与者'
    end
  end

  # 检查是否是前三名
  def is_top_three?
    rank <= 3
  end

  # 生成证书图片路径
  def certificate_image_path
    "/certificates/flower_certificate_#{certificate_id}.png"
  end

  # 生成证书分享链接
  def share_url
    "#{Rails.application.config.base_url}/flower_certificates/#{certificate_id}"
  end

  # 类方法

  # 为活动生成前三名证书
  def self.generate_top_three_certificates(event)
    # 计算活动中的小红花排行榜
    flower_stats = Flower.joins(:recipient)
                          .joins(check_in: :event_enrollment)
                          .where(event_enrollments: { reading_event_id: event.id })
                          .group('recipients.id')
                          .sum(:amount)

    # 排序并获取前三名
    top_users = flower_stats.sort_by { |user_id, flowers| -flowers }
                         .first(3)
                         .map.with_index(1) { |(user_id, flowers), index| [user_id, flowers, index] }

    certificates = []

    top_users.each do |user_id, total_flowers, rank|
      user = User.find(user_id)
      certificate = create!(
        user: user,
        reading_event: event,
        rank: rank,
        total_flowers: total_flowers
      )
      certificates << certificate
    end

    certificates
  end

  # 获取用户的所有小红花证书
  def self.for_user_all(user)
    for_user(user).ranked
  end

  # 检查证书是否有效
  def valid_certificate?
    reading_event&.status == 'completed'
  end

  # API响应格式
  def as_json_for_api
    {
      id: id,
      certificate_id: certificate_id,
      rank: rank,
      rank_display: rank_display,
      honor_level: honor_level,
      total_flowers: total_flowers,
      user: user.as_json_for_api,
      reading_event: reading_event.as_json_for_api,
      is_top_three: is_top_three?,
      valid_certificate: valid_certificate?,
      share_url: share_url,
      certificate_image_url: certificate_image_path,
      created_at: created_at
    }
  end

  private

  # 生成唯一的证书编号
  def generate_certificate_id
    return if certificate_id.present?

    loop do
      id = "FC#{Time.current.strftime('%Y%m%d')}#{SecureRandom.hex(4).upcase}"
      break self.certificate_id = id unless FlowerCertificate.exists?(certificate_id: id)
    end
  end
end