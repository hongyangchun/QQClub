class Enrollment < ApplicationRecord
  # 关联
  belongs_to :user
  belongs_to :reading_event
  has_many :check_ins, dependent: :destroy

  # 验证
  validates :user_id, uniqueness: { scope: :reading_event_id, message: "已经报名该活动" }

  # 枚举
  enum :payment_status, { unpaid: 0, paid: 1, refunded: 2 }
  enum :role, { participant: 0, leader: 1 }

  # 计算打卡完成率
  def completion_rate
    total_days = reading_event.reading_schedules.count
    return 0 if total_days.zero?

    completed_days = check_ins.where.not(status: :missed).count
    (completed_days.to_f / total_days * 100).round(2)
  end

  # 计算应退押金
  def refund_amount_calculated
    reading_event.deposit * (completion_rate / 100.0)
  end

  # 权限检查方法
  def is_current_leader?
    return false unless reading_event&.in_progress?
    reading_event.leader_id == user_id
  end

  def is_current_daily_leader?(schedule)
    return false unless reading_event&.in_progress?
    return false unless schedule&.reading_event_id == reading_event_id

    # 检查是否是当天的领读人
    schedule.daily_leader_id == user_id &&
    schedule.date == Date.today
  end

  def is_current_participant?
    reading_event&.in_progress? || reading_event&.enrolling?
  end

  # 活动结束时重置角色
  def reset_roles_on_event_completion!
    return unless reading_event&.completed?

    update!(role: :participant)  # 所有人都变回普通参与者
  end
end
