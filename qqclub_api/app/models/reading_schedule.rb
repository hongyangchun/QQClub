# == Schema Information
#
# Table name: reading_schedules
#
#  id               :integer          not null, primary key
#  reading_event_id :integer          not null
#  day_number       :integer          not null
#  date             :date             not null
#  reading_progress :string           not null
#  daily_leader_id  :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_reading_schedules_on_date                           (date)
#  index_reading_schedules_on_daily_leader_id                (daily_leader_id)
#  index_reading_schedules_on_reading_event_id               (reading_event_id)
#  index_reading_schedules_on_reading_event_id_and_day_number  (reading_event_id, day_number) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (daily_leader_id => users.id)
#  fk_rails_...  (reading_event_id => reading_events.id)
#

class ReadingSchedule < ApplicationRecord
  # 关联关系
  belongs_to :reading_event
  belongs_to :daily_leader, class_name: 'User', optional: true
  has_many :check_ins, dependent: :destroy
  has_one :daily_leading, dependent: :destroy
  has_many :flowers, dependent: :destroy

  # 验证规则
  validates :day_number, presence: true, numericality: { greater_than: 0 }
  validates :reading_progress, presence: true, length: { maximum: 200 }
  validates :date, presence: true
  validates_uniqueness_of :day_number, scope: :reading_event_id
  validate :date_within_event_period
  validate :leader_must_be_event_participant, if: :daily_leader_id?

  # 作用域
  scope :today, -> { where(date: Date.current) }
  scope :past, -> { where('date < ?', Date.current) }
  scope :future, -> { where('date > ?', Date.current) }
  scope :with_leader, -> { where.not(daily_leader_id: nil) }
  scope :without_leader, -> { where(daily_leader_id: nil) }
  scope :with_leading_content, -> { joins(:daily_leading) }
  scope :chronological, -> { order(:day_number) }
  scope :by_date, ->(direction = :asc) { order(date: direction) }

  # 委托方法
  delegate :title, :activity_mode, :in_progress?, to: :reading_event, prefix: true

  # 状态方法
  def today?
    date == Date.current
  end

  def past?
    date < Date.current
  end

  def future?
    date > Date.current
  end

  def current_day?
    reading_event.in_progress? && (date == Date.current || (date < Date.current && !completed?))
  end

  def can_assign_leader?
    daily_leader_id.blank? && (future? || current_day?)
  end

  def can_publish_leading_content?
    # 领读人权限窗口：前一天可以发布内容
    return false unless daily_leader.present?

    permission_start = date - 1.day
    permission_end = date

    Date.current.between?(permission_start, permission_end)
  end

  def can_give_flowers?
    # 小红花发放权限窗口：当天和后一天
    return false unless check_ins.any?

    permission_start = date
    permission_end = date + 1.day

    Date.current.between?(permission_start, permission_end)
  end

  def has_leading_content?
    daily_leading.present?
  end

  def has_check_ins?
    check_ins.exists?
  end

  def has_flowers?
    flowers.exists?
  end

  def completed?
    return true if past? && has_check_ins?
    return true if reading_event.completed?
    false
  end

  # 领读人分配方法
  def assign_leader!(user)
    return false unless can_assign_leader?
    return false unless reading_event.participants.include?(user)

    transaction do
      update!(daily_leader: user)
      notify_leader_assignment(user)
    end
    true
  end

  def remove_leader!
    return false unless daily_leader.present?

    transaction do
      update!(daily_leader: nil)
      # 删除相关的领读内容
      daily_leading&.destroy
    end
    true
  end

  # 统计方法
  def participation_statistics
    {
      check_ins_count: check_ins.count,
      flowers_count: flowers.count,
      unique_participants: check_ins.distinct.count(:user_id),
      average_word_count: check_ins.average(:word_count)&.round(2) || 0
    }
  end

  def leading_content_status
    return 'no_leader' if daily_leader.blank?
    return 'content_published' if has_leading_content?
    return 'content_pending' if can_publish_leading_content?
    'content_overdue'
  end

  def flower_giving_status
    return 'no_check_ins' unless has_check_ins?
    return 'flowers_given' if has_flowers?
    return 'flowers_pending' if can_give_flowers?
    'flowers_overdue'
  end

  # 检查是否需要小组长补位
  def needs_backup?
    return false unless reading_event.in_progress?

    # 检查领读内容是否缺失
    content_missing = daily_leader.present? && !has_leading_content? && !can_publish_leading_content?

    # 检查小红花是否缺失
    flowers_missing = has_check_ins? && !has_flowers? && !can_give_flowers?

    content_missing || flowers_missing
  end

  # 获取补位权限
  def backup_permissions
    return {} unless reading_event.in_progress?

    {
      can_publish_content: reading_event.current_leader?(reading_event.leader),
      can_give_flowers: reading_event.current_leader?(reading_event.leader),
      content_deadline: date,
      flowers_deadline: date + 1.day
    }
  end

  # 通知方法
  def notify_leader_assignment(leader)
    # 发送领读人分配通知
    LeaderAssignmentService.notify_assignment(self, leader)
  end

  def notify_leading_content_published
    return unless daily_leader.present?

    # 发送领读内容发布通知
    LeaderAssignmentService.notify_content_published(self)
  end

  def notify_check_in_submitted(check_in)
    # 发送打卡提交通知给领读人和小组长
    CheckInNotificationService.notify_submitted(check_in)
  end

  def notify_flower_given(flower)
    # 发送小红花发放通知
    FlowerNotificationService.notify_given(flower)
  end

  private

  # 验证方法
  def date_within_event_period
    return unless date && reading_event

    if date < reading_event.start_date || date > reading_event.end_date
      errors.add(:date, "必须在活动时间范围内")
    end
  end

  def leader_must_be_event_participant
    return unless daily_leader_id && reading_event

    unless reading_event.participants.include?(daily_leader)
      errors.add(:daily_leader, "必须是活动的参与者")
    end
  end
end
