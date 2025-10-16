class DailyLeading < ApplicationRecord
  # 关联
  belongs_to :reading_schedule
  belongs_to :leader, class_name: "User"

  # 验证
  validates :reading_suggestion, presence: true
  validates :questions, presence: true
  validates :reading_schedule_id, uniqueness: { message: "今日已有领读内容" }
end
