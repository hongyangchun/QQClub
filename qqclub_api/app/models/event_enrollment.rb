# == Schema Information
#
# Table name: event_enrollments
#
#  id                     :integer          not null, primary key
#  reading_event_id       :integer          not null
#  user_id                :integer          not null
#  enrollment_type        :string           default("participant"), not null
#  status                 :string           default("enrolled"), not null
#  enrollment_date        :datetime         not null
#  completion_rate        :decimal(5, 2)    default(0.0), not null
#  check_ins_count        :integer          default(0), not null
#  leader_days_count      :integer          default(0), not null
#  flowers_received_count :integer          default(0), not null
#  fee_paid_amount        :decimal(10, 2)   default(0.0), not null
#  fee_refund_amount      :decimal(10, 2)   default(0.0), not null
#  refund_status          :string           default("pending"), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  idx_event_enrollments_enrollment_date  (enrollment_date)
#  idx_event_enrollments_enrollment_type  (enrollment_type)
#  idx_event_enrollments_status           (status)
#  index_event_enrollments_on_reading_event_id_and_user_id  (reading_event_id, user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (reading_event_id => reading_events.id)
#  fk_rails_...  (user_id => users.id)
#

class EventEnrollment < ApplicationRecord
  # 参与类型枚举
  enum :enrollment_type, {
    participant: 'participant',  # 参与者
    observer: 'observer'         # 围观者
  }, default: :participant

  # 报名状态枚举
  enum :status, {
    enrolled: 'enrolled',    # 已报名
    completed: 'completed',  # 已完成
    cancelled: 'cancelled'   # 已取消
  }, default: :enrolled

  # 退款状态枚举
  enum :refund_status, {
    pending: 'pending',    # 待处理
    refunded: 'refunded',  # 已退款
    forfeited: 'forfeited' # 没收
  }, default: :pending

  # 关联关系
  belongs_to :reading_event
  belongs_to :user

  has_many :check_ins, dependent: :destroy
  has_many :received_flowers, class_name: 'Flower', foreign_key: :recipient_id, dependent: :destroy
  has_many :given_flowers, class_name: 'Flower', foreign_key: :giver_id, dependent: :destroy
  has_many :daily_leading_assignments, class_name: 'ReadingSchedule', foreign_key: :daily_leader_id, dependent: :nullify
  has_many :participation_certificates, dependent: :destroy

  # 验证规则
  validates :enrollment_date, presence: true
  validates :completion_rate, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100
  }
  validates :fee_paid_amount, numericality: {
    greater_than_or_equal_to: 0
  }
  validates :fee_refund_amount, numericality: {
    greater_than_or_equal_to: 0
  }
  validate :cannot_enroll_if_event_completed
  validate :unique_enrollment_per_event

  # 作用域
  scope :participants, -> { where(enrollment_type: :participant) }
  scope :observers, -> { where(enrollment_type: :observer) }
  scope :enrolled, -> { where(status: :enrolled) }
  scope :completed, -> { where(status: :completed) }
  scope :cancelled, -> { where(status: :cancelled) }
  scope :active, -> { where(status: [:enrolled, :completed]) }
  scope :by_completion_rate, ->(direction = :desc) { order(completion_rate: direction) }
  scope :by_flowers_count, ->(direction = :desc) { order(flowers_received_count: direction) }

  # 类方法：计算报名统计
  def self.calculate_enrollment_statistics
    all_enrollments = includes(:user, :reading_event)

    {
      total_enrollments: all_enrollments.count,
      active_enrollments: all_enrollments.where(status: 'enrolled').count,
      completed_enrollments: all_enrollments.where(status: 'completed').count,
      cancelled_enrollments: all_enrollments.where(status: 'cancelled').count,
      participants_count: all_enrollments.where(enrollment_type: 'participant').count,
      observers_count: all_enrollments.where(enrollment_type: 'observer').count,
      total_fees_collected: all_enrollments.sum(:fee_paid_amount),
      total_refunds_processed: all_enrollments.sum(:fee_refund_amount),
      enrollment_trend: calculate_enrollment_trend(all_enrollments),
      completion_trend: calculate_completion_trend(all_enrollments)
    }
  end

  # 委托方法
  delegate :title, :book_name, :activity_mode, :completion_standard, to: :reading_event, prefix: true
  delegate :nickname, to: :user, prefix: true

  # 状态方法（公开方法供其他模型调用）
  def can_participate?
    enrolled? && participant?
  end

  def can_check_in?
    can_participate? && reading_event.in_progress?
  end

  def can_receive_flowers?
    can_participate? && check_ins.any?
  end

  def can_give_flowers?
    can_participate? && reading_event.in_progress?
  end

  def can_cancel?
    enrolled? && !reading_event.in_progress?
  end

  def cancellation_error_message
    return "报名已取消，无法再次取消" if cancelled?
    return "活动已开始，无法取消报名" if reading_event.in_progress?
    return "活动已完成，无法取消报名" if reading_event.completed?
    "无法取消报名"
  end

  def is_completed?
    completion_rate >= reading_event.completion_standard
  end

  # 统计方法
  def update_completion_rate!
    new_rate = calculate_completion_rate
    update!(completion_rate: new_rate)

    # 如果完成率达到标准，更新状态
    if is_completed? && enrolled?
      update!(status: :completed)
    end
  end

  def calculate_completion_rate
    case reading_event.activity_mode
    when 'note_checkin'
      calculate_note_checkin_completion
    when 'free_discussion'
      calculate_free_discussion_completion
    when 'video_conference'
      calculate_video_conference_completion
    when 'offline_meeting'
      calculate_offline_meeting_completion
    else
      0.0
    end
  end

  # 费用相关方法
  def calculate_refund_amount
    return 0.0 if reading_event.fee_type != 'deposit'

    DepositRefundCalculator.calculate_refund_amount(user, reading_event)
  end

  def process_refund!
    return unless reading_event.fee_type == 'deposit'
    return if refund_status != 'pending'

    refund_amount = calculate_refund_amount

    transaction do
      update!(
        fee_refund_amount: refund_amount,
        refund_status: refund_amount > 0 ? 'refunded' : 'forfeited'
      )

      # 这里应该调用实际的退款服务
      # RefundService.process(user, refund_amount) if refund_amount > 0
    end
  end

  # 证书相关方法
  def eligible_for_completion_certificate?
    is_completed? && participation_certificates.where(certificate_type: 'completion').empty?
  end

  def eligible_for_flower_certificate?(rank = nil)
    return false unless flowers_received_count > 0

    if rank
      # 检查是否在指定排名
      top_rankings = reading_event.event_enrollments
        .where('flowers_received_count > 0')
        .order(flowers_received_count: :desc)
        .limit(rank)

      top_rankings.include?(self) &&
        participation_certificates.where(certificate_type: "flower_top#{rank}").empty?
    else
      # 只要有小红花就可能有资格
      flowers_received_count > 0
    end
  end

  # 通知方法
  def notify_enrollment_confirmation
    # 发送报名确认通知
    EnrollmentNotificationService.confirm_enrollment(self)
  end

  def notify_completion_achievement
    return unless is_completed?

    # 发送完成成就通知
    EnrollmentNotificationService.notify_completion(self)
  end

  def notify_certificate_issued(certificate)
    # 发送证书颁发通知
    EnrollmentNotificationService.notify_certificate_issued(self, certificate)
  end

  # API响应格式化
  def as_json_for_api(options = {})
    base_data = {
      id: id,
      enrollment_type: enrollment_type,
      status: status,
      enrollment_date: enrollment_date,
      completion_rate: completion_rate,
      check_ins_count: check_ins_count,
      leader_days_count: leader_days_count,
      flowers_received_count: flowers_received_count,
      fee_paid_amount: fee_paid_amount,
      fee_refund_amount: fee_refund_amount,
      refund_status: refund_status,
      created_at: created_at,
      updated_at: updated_at,
      is_completed: is_completed?,
      can_participate: can_participate?,
      can_check_in: can_check_in?,
      can_receive_flowers: can_receive_flowers?,
      can_give_flowers: can_give_flowers?,
      can_cancel: can_cancel?
    }

    # 可选包含关联数据
    if options[:include_user]
      base_data[:user] = user.as_json_for_api
    end

    if options[:include_reading_event]
      base_data[:reading_event] = reading_event.as_json_for_api
    end

    if options[:include_check_ins]
      base_data[:check_ins] = check_ins.includes(:user).map do |check_in|
        check_in.as_json_for_api(include_user: false)
      end
    end

    if options[:include_flowers]
      base_data[:flowers] = received_flowers.includes(:giver).map do |flower|
        {
          id: flower.id,
          amount: flower.amount,
          flower_type: flower.flower_type,
          comment: flower.comment,
          giver: flower.giver.as_json_for_api,
          created_at: flower.created_at
        }
      end
    end

    if options[:include_certificates]
      base_data[:certificates] = participation_certificates.map do |cert|
        {
          id: cert.id,
          certificate_type: cert.certificate_type,
          certificate_number: cert.certificate_number,
          issued_at: cert.issued_at,
          is_public: cert.is_public,
          certificate_url: cert.certificate_url
        }
      end
    end

    if options[:include_statistics]
      base_data[:statistics] = {
        completion_percentage: completion_rate,
        attendance_rate: reading_event.reading_schedules.any? ? (check_ins_count.to_f / reading_event.reading_schedules.count * 100).round(2) : 0,
        flower_ranking_in_event: calculate_flower_ranking_in_event
      }
    end

    base_data
  end

  private

  # 验证方法
  def cannot_enroll_if_event_completed
    if reading_event.completed? && enrolled?
      errors.add(:base, "不能报名已完成的活动")
    end
  end

  def unique_enrollment_per_event
    return unless reading_event_id && user_id

    existing = EventEnrollment.where(
      reading_event_id: reading_event_id,
      user_id: user_id
    ).where.not(id: id)

    if existing.exists?
      errors.add(:base, "已经报名过此活动")
    end
  end

  # 完成率计算方法
  def calculate_note_checkin_completion
    schedules = reading_event.reading_schedules
    total_days = calculate_total_reading_days(schedules, reading_event)

    return 0.0 if total_days == 0

    # 获取实际打卡次数
    check_ins_count = check_ins
      .where(schedule: schedules)
      .where.not(status: 'supplement')
      .count

    # 获取担任领读天数
    leader_days_count = daily_leading_assignments
      .where(reading_schedule: schedules)
      .count

    # 计算完成率：(打卡次数 + 担任领读天数) / 总天数
    completed_days = check_ins_count + leader_days_count
    (completed_days.to_f / total_days * 100).round(2)
  end

  def calculate_free_discussion_completion
    # 自由讨论模式：基于参与度计算
    # 这里可以基于发帖、回复等互动数据计算
    # 暂时使用打卡次数作为基础指标
    schedules = reading_event.reading_schedules
    total_days = calculate_total_reading_days(schedules, reading_event)

    return 0.0 if total_days == 0

    participation_count = check_ins.where(schedule: schedules).count
    (participation_count.to_f / total_days * 100).round(2)
  end

  def calculate_video_conference_completion
    # 视频会议模式：基于出席率计算
    # 这里需要检查用户的会议出席记录
    # 暂时返回基于日程的简单计算
    schedules = reading_event.reading_schedules
    total_sessions = schedules.count

    return 0.0 if total_sessions == 0

    # 假设用户参与了所有会议（实际应该检查出席记录）
    attendance_count = total_sessions # 这里应该是实际的出席次数
    (attendance_count.to_f / total_sessions * 100).round(2)
  end

  def calculate_offline_meeting_completion
    # 线下交流模式：基于出席率计算
    # 类似视频会议模式，但针对线下活动
    schedules = reading_event.reading_schedules
    total_meetings = schedules.count

    return 0.0 if total_meetings == 0

    # 假设用户参与了所有会议（实际应该检查出席记录）
    attendance_count = total_meetings # 这里应该是实际的出席次数
    (attendance_count.to_f / total_meetings * 100).round(2)
  end

  def calculate_total_reading_days(schedules, event)
    if event.weekend_rest
      # 排除周末
      schedules.where.not(date: [Date::SATURDAY, Date::SUNDAY]).count
    else
      schedules.count
    end
  end

  def calculate_flower_ranking_in_event
    return nil unless flowers_received_count > 0

    # 获取活动中所有有小红花的参与者，按数量排序
    ranked_participants = reading_event.event_enrollments
                           .where('flowers_received_count > 0')
                           .order(flowers_received_count: :desc)
                           .pluck(:id)

    ranked_participants.index(id) + 1
  end
end