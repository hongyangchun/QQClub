# == Schema Information
#
# Table name: check_ins
#
#  id                :integer          not null, primary key
#  user_id           :integer          not null
#  reading_schedule_id :integer        not null
#  enrollment_id     :integer          not null
#  content           :text             not null
#  word_count        :integer          default(0), not null
#  status            :integer          default(0), not null
#  submitted_at      :datetime         not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_check_ins_on_reading_schedule_id  (reading_schedule_id)
#  index_check_ins_on_submitted_at        (submitted_at)
#  index_check_ins_on_user_id             (user_id)
#  index_check_ins_on_user_id_and_reading_schedule_id  (user_id, reading_schedule_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (enrollment_id => event_enrollments.id)
#  fk_rails_...  (reading_schedule_id => reading_schedules.id)
#  fk_rails_...  (user_id => users.id)
#

class CheckIn < ApplicationRecord
  # 打卡状态枚举
  enum :status, {
    normal: 0,      # 正常打卡
    supplement: 1,  # 补卡
    late: 2         # 迟到
  }, default: :normal

  # 关联关系
  belongs_to :user
  belongs_to :reading_schedule
  belongs_to :enrollment, class_name: 'EventEnrollment'
  has_many :flowers, dependent: :destroy
  has_one :reading_event, through: :reading_schedule
  has_many :comments, as: :commentable, dependent: :destroy

  # 验证规则
  validates :content, presence: true, length: { minimum: 50, maximum: 2000 }
  validates :word_count, numericality: { greater_than_or_equal_to: 0 }
  validates :user_id, uniqueness: { scope: :reading_schedule_id, message: "今日已打卡" }
  validate :must_be_active_participant
  validate :schedule_within_activity_period
  validate :content_word_count_limit
  validate :cannot_check_in_after_deadline, on: :create

  # 回调
  before_validation :calculate_word_count, if: :content_changed?
  before_validation :set_status, on: :create
  before_create :set_submitted_at
  after_create :update_enrollment_stats
  after_create :notify_check_in_submitted
  after_destroy :rollback_enrollment_stats

  # 作用域
  scope :today, -> { joins(:reading_schedule).where(reading_schedules: { date: Date.current }) }
  scope :normal, -> { where(status: :normal) }
  scope :supplement, -> { where(status: :supplement) }
  scope :late, -> { where(status: :late) }
  scope :recent, -> { order(submitted_at: :desc) }
  scope :by_word_count, ->(direction = :desc) { order(word_count: direction) }

  # 委托方法
  delegate :title, to: :reading_event, prefix: true
  delegate :nickname, to: :user, prefix: true
  delegate :date, to: :reading_schedule, prefix: true

  # 状态方法
  def today?
    reading_schedule.today?
  end

  def on_time?
    return true if status == 'normal'
    false
  end

  def is_supplement?
    status == 'supplement'
  end

  def is_late?
    status == 'late'
  end

  def can_be_edited?
    # 活动结束后不能编辑
    return false unless reading_event
    reading_event.end_date >= Date.current
  end

  def can_receive_flowers?
    flowers_count < 3 # 每个打卡最多3朵小红花
  end

  def can_be_deleted?
    # 活动结束后不能删除
    return false unless reading_event
    reading_event.end_date >= Date.current
  end

  # 统计方法
  def flowers_count
    flowers.count
  end

  def total_flowers_received
    flowers.sum(&:amount) if flowers.respond_to?(:sum)
  end

  def engagement_score
    # 计算参与度分数：字数分数 + 小红花分数
    word_score = [word_count / 100.0, 10.0].min # 最多10分
    flower_score = flowers_count * 2.0 # 每朵小红花2分
    (word_score + flower_score).round(2)
  end

  # 小红花相关方法
  def give_flower!(giver, comment = nil)
    return false unless can_receive_flowers?
    return false if giver == user # 不能给自己发小红花

    # 检查发放权限
    unless reading_event.can_give_flowers?(giver, reading_schedule)
      return false
    end

    transaction do
      flower = flowers.create!(
        giver: giver,
        recipient: user,
        comment: comment,
        reading_schedule: reading_schedule
      )

      # 更新接收者的统计
      enrollment.increment!(:flowers_received_count)

      # 发送通知
      notify_flower_given(flower)
    end
    true
  end

  # 内容方法
  def content_preview(length = 100)
    content.truncate(length)
  end

  def reading_time_estimate
    # 基于字数估算阅读时间（假设每分钟200字）
    (word_count / 200.0).ceil
  end

  # 格式化内容
  def formatted_content(options = {})
    ContentFormatterService.format(content, options)
  end

  # 内容摘要
  def content_summary(max_length = 200)
    ContentFormatterService.generate_summary(content, max_length)
  end

  # 提取关键词
  def keywords(max_count = 5)
    ContentFormatterService.extract_keywords(content, max_count)
  end

  # 内容质量分数
  def quality_score
    ContentFormatterService.calculate_quality_score(content)
  end

  # 内容合规性检查
  def compliance_check
    ContentFormatterService.check_compliance(content)
  end

  # 是否为高质量内容
  def high_quality?
    quality_score >= 50
  end

  # 是否有格式问题
  def has_formatting_issues?
    check = compliance_check
    check[:issues].any? { |issue| issue[:type] == 'poor_formatting' }
  end

  # 是否包含敏感词
  def contains_sensitive_words?
    check = compliance_check
    check[:issues].any? { |issue| issue[:type] == 'sensitive_words' }
  end

  # API响应格式化
  def as_json_for_api(options = {})
    base_data = {
      id: id,
      content: content,
      word_count: word_count,
      status: status,
      submitted_at: submitted_at,
      created_at: created_at,
      updated_at: updated_at,
      engagement_score: engagement_score,
      quality_score: quality_score,
      high_quality: high_quality?
    }

    # 可选包含关联数据
    if options[:include_user]
      base_data[:user] = user.as_json_for_api
    end

    if options[:include_reading_schedule]
      base_data[:reading_schedule] = {
        id: reading_schedule.id,
        day_number: reading_schedule.day_number,
        date: reading_schedule.date,
        reading_progress: reading_schedule.reading_progress
      }
    end

    if options[:include_reading_event]
      base_data[:reading_event] = {
        id: reading_event.id,
        title: reading_event.title,
        book_name: reading_event.book_name
      }
    end

    if options[:include_flowers]
      base_data[:flowers] = flowers.map do |flower|
        {
          id: flower.id,
          amount: flower.amount,
          flower_type: flower.flower_type,
          comment: flower.comment,
          giver: flower.giver.as_json_for_api,
          created_at: flower.created_at
        }
      end
      base_data[:flowers_count] = flowers_count
      base_data[:total_flowers_received] = total_flowers_received
    end

    if options[:include_comments]
      base_data[:comments] = comments.map(&:as_json_for_api)
      base_data[:comments_count] = comments.count
    end

    # 内容相关
    if options[:include_content_analysis]
      base_data[:content_preview] = content_preview(options[:preview_length] || 100)
      base_data[:reading_time_estimate] = reading_time_estimate
      base_data[:keywords] = keywords
      base_data[:content_summary] = content_summary
    end

    base_data
  end

  private

  # 验证方法
  def must_be_active_participant
    return unless enrollment && reading_event

    # 直接检查报名状态和类型，避免调用私有方法
    unless enrollment.enrolled? && enrollment.participant?
      errors.add(:base, "您不是该活动的有效参与者")
    end
  end

  def schedule_within_activity_period
    return unless reading_schedule && reading_event

    schedule_date = reading_schedule.date
    unless schedule_date.between?(reading_event.start_date, reading_event.end_date)
      errors.add(:base, "打卡日期不在活动期间内")
    end
  end

  def content_word_count_limit
    return unless content

    if word_count < 50
      errors.add(:content, "内容太短，至少需要50个字")
    elsif word_count > 2000
      errors.add(:content, "内容太长，最多2000个字")
    end
  end

  def cannot_check_in_after_deadline
    return unless reading_schedule

    # 当天的打卡可以在晚上11:59前提交
    schedule_date = reading_schedule.date
    deadline = schedule_date.to_time.end_of_day

    if Time.current > deadline && status == 'normal'
      errors.add(:base, "打卡时间已过，只能补卡")
    end
  end

  # 回调方法
  def calculate_word_count
    self.word_count = content.to_s.strip.length
  end

  def set_status
    schedule_date = reading_schedule.date
    current_time = Time.current

    if schedule_date == Date.current
      self.status = 'normal'
    elsif schedule_date < Date.current
      self.status = 'supplement'
    elsif current_time > schedule_date.to_time.end_of_day
      self.status = 'late'
    end
  end

  def set_submitted_at
    self.submitted_at ||= Time.current
  end

  def update_enrollment_stats
    return unless enrollment

    enrollment.increment!(:check_ins_count)
    enrollment.update_completion_rate!
  end

  def rollback_enrollment_stats
    return unless enrollment

    # 减少打卡次数
    enrollment.decrement!(:check_ins_count)

    # 减少小红花数量（如果有）
    flowers_count = flowers.count
    if flowers_count > 0
      enrollment.decrement!(:flowers_received_count, flowers_count)
    end

    # 重新计算完成率
    enrollment.update_completion_rate!
  end

  # 通知方法
  def notify_check_in_submitted
    # 发送打卡提交通知
    CheckInNotificationService.notify_submitted(self)
  end

  def notify_flower_given(flower)
    # 发送小红花通知
    FlowerNotificationService.notify_given(flower)
  end

  # 是否获得小红花
  def has_flower?
    flower.present?
  end

  # 是否可以补卡
  def can_makeup?
    reading_schedule.date < Date.today &&
    reading_event.in_progress?
  end
end
