# == Schema Information
#
# Table name: content_reports
#
#  id          :integer          not null, primary key
#  user_id     :integer          not null, foreign_key
#  check_in_id :integer          not null, foreign_key
#  admin_id    :integer          foreign_key
#  reason      :enum             default("other"), not null
#  description :text
#  status      :enum             default("pending"), not null
#  admin_notes :text
#  reviewed_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_content_reports_on_check_in_id            (check_in_id)
#  index_content_reports_on_created_at             (created_at)
#  index_content_reports_on_reason                  (reason)
#  index_content_reports_on_status                  (status)
#  index_content_reports_on_user_id                 (user_id)
#  index_content_reports_unique_reporting (user_id, check_in_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (check_in_id => check_ins.id)
#  fk_rails_...  (user_id => users.id)
#

class ContentReport < ApplicationRecord
  # 举报原因枚举
  enum :reason, {
    sensitive_words: '敏感词',
    inappropriate_content: '不当内容',
    spam: '垃圾内容',
    other: '其他'
  }, default: :other

  # 处理状态枚举
  enum :status, {
    pending: '待处理',
    reviewed: '已查看',
    dismissed: '已忽略',
    action_taken: '已处理'
  }, default: :pending

  # 关联关系
  belongs_to :user
  belongs_to :check_in
  belongs_to :admin, class_name: 'User', optional: true

  # 验证规则
  validates :user_id, uniqueness: { scope: :check_in_id, message: '您已经举报过此内容' }
  validates :description, length: { maximum: 500 }
  validate :cannot_report_own_content

  # 回调
  after_create :notify_admins
  after_update :send_status_update_notification

  # 作用域
  scope :pending, -> { where(status: :pending) }
  scope :reviewed, -> { where.not(status: :pending) }
  scope :by_reason, ->(reason) { where(reason: reason) }
  scope :recent, -> { order(created_at: :desc) }

  # 委托方法
  delegate :content, to: :check_in, prefix: true
  delegate :nickname, to: :user, prefix: true
  delegate :created_at, to: :check_in, prefix: true

  # 状态方法
  def pending?
    status == 'pending'
  end

  def reviewed?
    reviewed_at.present?
  end

  def processed?
    %w[reviewed dismissed action_taken].include?(status.to_s)
  end

  def action_taken?
    status == 'action_taken'
  end

  # 操作方法
  def review!(admin:, notes: nil, action: :reviewed)
    return false unless admin.can_approve_events?

    transaction do
      update!(
        admin: admin,
        admin_notes: notes,
        status: action,
        reviewed_at: Time.current
      )

      # 根据处理结果执行相应操作
      case action.to_sym
      when :action_taken
        handle_content_action
      end

      log_review_action(admin, action)
    end

    true
  rescue => e
    Rails.logger.error "Content report review failed: #{e.message}"
    false
  end

  def dismiss!(admin:, notes: nil)
    review!(admin: admin, notes: notes, action: :dismissed)
  end

  # 类方法
  def self.statistics(days = 30)
    start_date = days.days.ago.to_date

    {
      total_reports: where('created_at >= ?', start_date).count,
      pending_reports: pending.where('created_at >= ?', start_date).count,
      by_reason: where('created_at >= ?', start_date).group(:reason).count,
      by_status: where('created_at >= ?', start_date).group(:status).count,
      daily_trends: where('created_at >= ?', start_date)
                   .group('DATE(created_at)')
                   .count
    }
  end

  def self.high_priority_reports
    # 需要优先处理的举报
    pending.joins(:check_in)
          .where('check_ins.created_at < ?', 1.hour.ago)
          .or(where(reason: :sensitive_words))
  end

  private

  # 验证方法
  def cannot_report_own_content
    if user_id == check_in.user_id
      errors.add(:base, '不能举报自己的内容')
    end
  end

  # 回调方法
  def notify_admins
    # 通知管理员有新的举报
    return unless Rails.env.production?

    # 这里可以实现邮件、短信或推送通知
    ContentModerationService.notify_admins_of_new_report(self)
  end

  def send_status_update_notification
    # 向举报人发送状态更新通知
    return unless saved_change_to_status?

    ContentModerationService.notify_reporter_of_status_change(self)
  end

  def handle_content_action
    # 处理内容（如隐藏、删除等）
    case reason.to_sym
    when :sensitive_words
      # 可以隐藏包含敏感词的内容
      check_in.update!(status: :hidden) if check_in.respond_to?(:status=)
    when :spam
      # 可以删除垃圾内容
      check_in.destroy
    end
  end

  def log_review_action(admin, action)
    # 记录管理员操作日志
    Rails.logger.info "ContentReport##{id} reviewed by #{admin.nickname} with action: #{action}"
  end
end