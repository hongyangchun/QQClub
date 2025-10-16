class Flower < ApplicationRecord
  # 关联
  belongs_to :check_in
  belongs_to :giver, class_name: "User"
  belongs_to :recipient, class_name: "User"
  belongs_to :reading_schedule

  # 验证
  validates :check_in_id, uniqueness: { message: "该打卡已获得小红花" }
  validate :daily_flower_limit
  validate :giver_is_daily_leader

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
