class ReadingSchedule < ApplicationRecord
  # 关联
  belongs_to :reading_event
  belongs_to :daily_leader, class_name: "User", optional: true
  has_many :check_ins, dependent: :destroy
  has_one :daily_leading, dependent: :destroy
  has_many :flowers, dependent: :destroy

  # 验证
  validates :day_number, presence: true
  validates :reading_progress, presence: true
  validates :date, presence: true

  # 作用域
  scope :today, -> { where(date: Date.today) }
  scope :past, -> { where("date < ?", Date.today) }
  scope :future, -> { where("date > ?", Date.today) }
end
