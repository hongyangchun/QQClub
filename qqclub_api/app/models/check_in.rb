class CheckIn < ApplicationRecord
  # 关联
  belongs_to :user
  belongs_to :reading_schedule
  belongs_to :enrollment
  has_one :flower, dependent: :destroy
  has_one :reading_event, through: :reading_schedule
  has_many :comments, as: :commentable, dependent: :destroy

  # 验证
  validates :content, presence: true, length: { minimum: 100 }
  validates :user_id, uniqueness: { scope: :reading_schedule_id, message: "今日已打卡" }
  validate :check_enrollment_exists

  # 枚举
  enum :status, { normal: 0, makeup: 1, missed: 2 }

  # 回调
  before_validation :calculate_word_count, if: :content_changed?
  before_create :set_submitted_at

  # 是否获得小红花
  def has_flower?
    flower.present?
  end

  # 是否可以补卡
  def can_makeup?
    reading_schedule.date < Date.today &&
    reading_event.in_progress?
  end

  private

  def calculate_word_count
    self.word_count = content.to_s.length
  end

  def set_submitted_at
    self.submitted_at ||= Time.current
  end

  def check_enrollment_exists
    unless enrollment && enrollment.reading_event_id == reading_schedule.reading_event_id
      errors.add(:base, "未报名该活动")
    end
  end
end
