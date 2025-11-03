# == Schema Information
#
# Table name: participation_certificates
#
#  id                :integer          not null, primary key
#  reading_event_id  :integer          not null
#  user_id           :integer          not null
#  certificate_type  :string           not null
#  certificate_number: string          not null
#  issued_at         :datetime         not null
#  achievement_data  :text
#  certificate_url   :string
#  is_public         :boolean          default(TRUE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  idx_certificates_event_id      (reading_event_id)
#  idx_certificates_is_public      (is_public)
#  idx_certificates_issued_at      (issued_at)
#  idx_certificates_type           (certificate_type)
#  idx_certificates_user_id        (user_id)
#  index_participation_certificates_on_certificate_number  (certificate_number) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (reading_event_id => reading_events.id)
#  fk_rails_...  (user_id => users.id)
#

class ParticipationCertificate < ApplicationRecord
  # 证书类型枚举
  enum :certificate_type, {
    completion: 'completion',           # 完成证书
    flower_top1: 'flower_top1',       # 小红花第一名证书
    flower_top2: 'flower_top2',       # 小红花第二名证书
    flower_top3: 'flower_top3',       # 小红花第三名证书
    custom: 'custom'                  # 自定义证书
  }, default: :completion

  # 关联关系
  belongs_to :reading_event
  belongs_to :user

  # 验证规则
  validates :certificate_number, presence: true, uniqueness: true
  validates :issued_at, presence: true
  validates :achievement_data, presence: true
  validate :certificate_number_format
  validate :user_must_be_event_participant
  validate :certificate_requirements_met

  # 作用域
  scope :is_public, -> { where(is_public: true) }
  scope :is_private, -> { where(is_public: false) }
  scope :completion, -> { where(certificate_type: :completion) }
  scope :flower_top, -> { where(certificate_type: [:flower_top1, :flower_top2, :flower_top3]) }
  scope :custom, -> { where(certificate_type: :custom) }
  scope :recent, -> { order(issued_at: :desc) }

  # 委托方法
  delegate :title, :book_name, to: :reading_event, prefix: true
  delegate :nickname, to: :user, prefix: true

  # 状态方法
  def completion_certificate?
    certificate_type == 'completion'
  end

  def flower_certificate?
    ['flower_top1', 'flower_top2', 'flower_top3'].include?(certificate_type)
  end

  def custom_certificate?
    certificate_type == 'custom'
  end

  def flower_rank
    return nil unless flower_certificate?

    case certificate_type
    when 'flower_top1' then 1
    when 'flower_top2' then 2
    when 'flower_top3' then 3
    end
  end

  # 证书生成方法
  def self.generate_completion_certificate(enrollment)
    return nil unless enrollment.is_completed?
    return nil if exists?(user: enrollment.user, reading_event: enrollment.reading_event, certificate_type: :completion)

    certificate_number = generate_certificate_number('COMP')
    achievement_data = build_completion_achievement_data(enrollment)

    create!(
      user: enrollment.user,
      reading_event: enrollment.reading_event,
      certificate_type: :completion,
      certificate_number: certificate_number,
      issued_at: Time.current,
      achievement_data: achievement_data.to_json,
      is_public: true
    )
  end

  def self.generate_flower_certificate(enrollment, rank)
    return nil unless enrollment.flowers_received_count > 0
    return nil if rank < 1 || rank > 3

    certificate_type = "flower_top#{rank}".to_sym
    return nil if exists?(user: enrollment.user, reading_event: enrollment.reading_event, certificate_type: certificate_type)

    certificate_number = generate_certificate_number('FLOWER')
    achievement_data = build_flower_achievement_data(enrollment, rank)

    create!(
      user: enrollment.user,
      reading_event: enrollment.reading_event,
      certificate_type: certificate_type,
      certificate_number: certificate_number,
      issued_at: Time.current,
      achievement_data: achievement_data.to_json,
      is_public: true
    )
  end

  def self.generate_custom_certificate(enrollment, custom_data = {})
    certificate_number = generate_certificate_number('CUSTOM')
    achievement_data = build_custom_achievement_data(enrollment, custom_data)

    create!(
      user: enrollment.user,
      reading_event: enrollment.reading_event,
      certificate_type: :custom,
      certificate_number: certificate_number,
      issued_at: Time.current,
      achievement_data: achievement_data.to_json,
      is_public: custom_data[:is_public] != false
    )
  end

  # 证书内容方法
  def certificate_title
    case certificate_type
    when 'completion'
      "#{reading_event.title} 完成证书"
    when 'flower_top1'
      "#{reading_event.title} 小红花冠军证书"
    when 'flower_top2'
      "#{reading_event.title} 小红花亚军证书"
    when 'flower_top3'
      "#{reading_event.title} 小红花季军证书"
    when 'custom'
      "#{reading_event.title} 荣誉证书"
    end
  end

  def certificate_description
    case certificate_type
    when 'completion'
      "完成#{reading_event.days_count}天共读活动，完成率达到#{enrollment.completion_rate}%"
    when 'flower_top1'
      "在#{reading_event.title}活动中获得小红花数量第一名（#{enrollment.flowers_received_count}朵）"
    when 'flower_top2'
      "在#{reading_event.title}活动中获得小红花数量第二名（#{enrollment.flowers_received_count}朵）"
    when 'flower_top3'
      "在#{reading_event.title}活动中获得小红花数量第三名（#{enrollment.flowers_received_count}朵）"
    when 'custom'
      achievement_data['description'] || "在#{reading_event.title}活动中表现优异"
    end
  end

  def achievement_info
    return {} unless achievement_data.is_a?(String) || achievement_data.is_a?(Hash)

    data = achievement_data.is_a?(String) ? JSON.parse(achievement_data) : achievement_data
    data.with_indifferent_access
  end

  def enrollment
    @enrollment ||= reading_event.event_enrollments.find_by(user: user)
  end

  # 分享方法
  def shareable_url
    # 生成证书分享链接
    "/certificates/#{certificate_number}"
  end

  def shareable_image_url
    # 生成证书图片URL
    certificate_url || "/certificates/#{certificate_number}/image"
  end

  def can_share?
    is_public? && certificate_url.present?
  end

  # 验证方法
  def verify_certificate
    {
      valid: true,
      certificate_number: certificate_number,
      holder_name: user.nickname,
      event_name: reading_event.title,
      issue_date: issued_at.strftime('%Y年%m月%d日'),
      certificate_type: certificate_type,
      verification_code: generate_verification_code
    }
  end

  private

  # 证书编号生成
  def self.generate_certificate_number(prefix)
    timestamp = Time.current.strftime('%Y%m%d')
    random = SecureRandom.hex(4).upcase
    "#{prefix}-#{timestamp}-#{random}"
  end

  # 成就数据构建
  def self.build_completion_achievement_data(enrollment)
    {
      completion_rate: enrollment.completion_rate,
      check_ins_count: enrollment.check_ins_count,
      leader_days_count: enrollment.leader_days_count,
      flowers_received_count: enrollment.flowers_received_count,
      event_duration: enrollment.reading_event.days_count,
      book_name: enrollment.reading_event.book_name,
      activity_mode: enrollment.reading_event.activity_mode,
      issue_date: Time.current.iso8601
    }
  end

  def self.build_flower_achievement_data(enrollment, rank)
    {
      rank: rank,
      flowers_count: enrollment.flowers_received_count,
      completion_rate: enrollment.completion_rate,
      check_ins_count: enrollment.check_ins_count,
      book_name: enrollment.reading_event.book_name,
      total_participants: enrollment.reading_event.participants_count,
      issue_date: Time.current.iso8601
    }
  end

  def self.build_custom_achievement_data(enrollment, custom_data)
    {
      description: custom_data[:description],
      custom_fields: custom_data[:custom_fields] || {},
      completion_rate: enrollment.completion_rate,
      check_ins_count: enrollment.check_ins_count,
      flowers_received_count: enrollment.flowers_received_count,
      book_name: enrollment.reading_event.book_name,
      issue_date: Time.current.iso8601
    }
  end

  # 验证方法
  def certificate_number_format
    return unless certificate_number

    unless certificate_number.match?(/\A[A-Z]+-\d{8}-[A-F0-9]{8}\z/)
      errors.add(:certificate_number, "格式不正确")
    end
  end

  def user_must_be_event_participant
    return unless user && reading_event

    unless reading_event.participants.include?(user)
      errors.add(:user, "不是该活动的参与者")
    end
  end

  def certificate_requirements_met
    return unless user && reading_event && certificate_type

    case certificate_type
    when 'completion'
      unless enrollment&.is_completed?
        errors.add(:base, "用户未达到完成证书的颁发条件")
      end
    when 'flower_top1', 'flower_top2', 'flower_top3'
      unless enrollment&.flowers_received_count&.positive?
        errors.add(:base, "用户未达到小红花证书的颁发条件")
      end
    end
  end

  def generate_verification_code
    # 生成验证码用于证书验证
    Digest::MD5.hexdigest("#{certificate_number}-#{user_id}-#{reading_event_id}")[0, 8].upcase
  end
end