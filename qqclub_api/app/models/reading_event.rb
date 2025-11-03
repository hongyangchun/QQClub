class ReadingEvent < ApplicationRecord
  # 活动状态枚举 - 简化流程：移除草稿状态，直接进入报名中
  enum :status, {
    enrolling: 0,    # 报名中（创建后的默认状态）
    in_progress: 1,  # 进行中
    completed: 2     # 已完成
  }, default: :enrolling

  # 审批状态枚举
  enum :approval_status, {
    pending: 0,      # 待审批
    approved: 1,     # 已批准
    rejected: 2      # 已拒绝
  }, default: :pending

  # 活动模式枚举
  enum :activity_mode, {
    note_checkin: 'note_checkin',        # 笔记打卡
    free_discussion: 'free_discussion',  # 自由讨论
    video_conference: 'video_conference', # 视频会议
    offline_meeting: 'offline_meeting'    # 线下交流
  }, default: :note_checkin

  # 领读方式枚举
  enum :leader_assignment_type, {
    voluntary: 'voluntary',  # 自由领读
    random: 'random',        # 随机领读
    disabled: 'disabled'      # 无领读
  }, default: :voluntary

  # 费用类型枚举
  enum :fee_type, {
    free: 'free',       # 免费
    deposit: 'deposit', # 押金制
    paid: 'paid'        # 收费制
  }, default: :free

  # 关联关系
  belongs_to :leader, class_name: 'User', foreign_key: :leader_id
  belongs_to :approver, class_name: 'User', foreign_key: :approved_by_id, optional: true
  belongs_to :escalated_by, class_name: 'User', foreign_key: :escalated_by_user_id, optional: true

  has_many :event_enrollments, dependent: :destroy, class_name: 'EventEnrollment'
  has_many :participants, through: :event_enrollments, source: :user
  has_many :reading_schedules, dependent: :destroy
  has_many :participation_certificates, dependent: :destroy

  # 验证规则
  validates :title, presence: true, length: { minimum: 5, maximum: 100 }
  validates :book_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :start_date, :end_date, presence: true
  validates :max_participants, numericality: {
    greater_than: 0,
    less_than_or_equal_to: 50
  }
  validates :min_participants, numericality: {
    greater_than: 0,
    less_than_or_equal_to: ->(event) { event.max_participants || 50 }
  }
  validates :fee_amount, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 500
  }
  validates :leader_reward_percentage, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 100
  }
  validates :completion_standard, numericality: {
    greater_than_or_equal_to: 60,
    less_than_or_equal_to: 100
  }
  validate :end_date_after_start_date
  validate :enrollment_deadline_before_start_date, if: :enrollment_deadline?
  validate :min_participants_not_greater_than_max

  # 作用域
  scope :with_details, -> { includes(:leader, :reading_schedules, :event_enrollments => :user) }
  scope :filter_by_status, ->(status) { where(status: status) if status.present? }
  scope :filter_by_mode, ->(mode) { where(activity_mode: mode) if mode.present? }
  scope :filter_by_fee_type, ->(fee_type) { where(fee_type: fee_type) if fee_type.present? }
  scope :upcoming, -> { where('start_date > ?', Date.current) }
  scope :active, -> { where(status: [:enrolling, :in_progress]) }
  scope :enrolling, -> { where(status: :enrolling) }
  scope :in_progress, -> { where(status: :in_progress) }
  scope :completed, -> { where(status: :completed) }

  # 委托方法
  delegate :nickname, to: :leader, prefix: true

  # 计算方法
  def service_fee
    fee_amount * 0.2
  end

  def deposit
    fee_amount * 0.8
  end

  def days_count
    return 0 unless start_date && end_date
    (end_date - start_date).to_i + 1
  end

  # 审批相关方法
  def approve!(admin_user)
    update!(
      approval_status: :approved,
      approved_by_id: admin_user.id,
      approved_at: Time.current
    )
  end

  def reject!(admin_user, reason = nil)
    update!(
      approval_status: :rejected,
      approved_by_id: admin_user.id,
      approved_at: Time.current,
      rejection_reason: reason
    )
  end

  def approved?
    approval_status == 'approved'
  end

  def pending_approval?
    approval_status == 'pending'
  end

  def rejected?
    approval_status == 'rejected'
  end

  # 审批工作流相关方法
  def can_submit_for_approval?
    draft? && !submitted_for_approval_at.present?
  end

  def can_resubmit_for_approval?
    rejected? && rejection_reason.present?
  end

  def can_be_approved_by?(admin_user)
    pending_approval? && admin_user.can_approve_events?
  end

  def can_be_rejected_by?(admin_user)
    pending_approval? && admin_user.can_approve_events?
  end

  def submit_for_approval!(workflow_type = :standard)
    return false unless can_submit_for_approval?

    service = ActivityApprovalWorkflowService.submit_for_approval!(self, workflow_type: workflow_type)
    service.success?
  end

  def process_approval!(admin_user, reason: nil, notes: nil)
    return false unless can_be_approved_by?(admin_user)

    service = ActivityApprovalWorkflowService.approve!(self, admin_user, reason: reason, notes: notes)
    service.success?
  end

  def process_rejection!(admin_user, reason, notes: nil)
    return false unless can_be_rejected_by?(admin_user)

    service = ActivityApprovalWorkflowService.reject!(self, admin_user, reason, notes: notes)
    service.success?
  end

  def escalate_approval!(admin_user, escalation_reason)
    service = ActivityApprovalWorkflowService.escalate!(self, admin_user, escalation_reason)
    service.success?
  end

  # 领读人分配方法
  def assign_daily_leaders!(assignment_type = nil, options = {})
    return unless approved? && reading_schedules.any?

    # 使用增强的LeaderAssignmentService
    service = LeaderAssignmentService.auto_assign_leaders!(self, assignment_type: assignment_type, options: options)
    service.success?
  end

  def assign_random_leaders!
    assign_daily_leaders!(:random)
  end

  # 活动完成时重置所有角色
  def complete_event!
    transaction do
      update!(status: :completed)

      # 重置所有参与者的角色
      enrollments.each do |enrollment|
        enrollment.reset_roles_on_event_completion!
      end

      # 生成活动总结（可选）
      generate_event_summary
    end
  end

  # 检查当前用户是否是有效的小组长
  def current_leader?(user)
    return false unless in_progress?
    leader_id == user.id
  end

  # 检查当前用户是否是有效的领读人（3天权限窗口）
  def current_daily_leader?(user, schedule = nil)
    return false unless in_progress?

    if schedule.present?
      return false unless schedule.reading_event_id == id
      return false unless schedule.daily_leader_id == user.id

      # 3天权限窗口：前一天、当天、后一天
      leader_date = schedule.date
      today = Date.today

      # 检查今天是否在领读人的权限窗口内
      (leader_date - 1.day) <= today && today <= (leader_date + 1.day)
    else
      # 查找用户作为领读人的所有schedule，检查是否在权限窗口内
      user_schedules = reading_schedules.where(daily_leader: user)
      return false if user_schedules.empty?

      user_schedules.any? do |schedule|
        leader_date = schedule.date
        today = Date.today
        (leader_date - 1.day) <= today && today <= (leader_date + 1.day)
      end
    end
  end

  # 检查用户是否有权限发布领读内容（前一天权限 + 小组长补位）
  def can_publish_leading_content?(user, schedule)
    return false unless in_progress?
    return false unless schedule.reading_event_id == id

    # 小组长全程具备发布权限（补位机制）
    return true if current_leader?(user)

    # 领读人权限检查
    return false unless schedule.daily_leader_id == user.id

    # 允许前一天发布领读内容
    schedule.date >= Date.today
  end

  # 检查用户是否有权限发放小红花（当天和后一天权限 + 小组长补位）
  def can_give_flowers?(user, schedule)
    return false unless in_progress?

    # 小组长全程具备发小红花权限（补位机制）
    return true if current_leader?(user)

    # 领读人权限检查
    user_leading_schedules = reading_schedules.where(daily_leader: user)
    return false if user_leading_schedules.empty?

    # 检查是否有schedule在小红花发放权限窗口内
    leader_dates = user_leading_schedules.pluck(:date)
    today = Date.today

    leader_dates.any? do |leader_date|
      # 当天和后一天可以发小红花
      leader_date <= today && today <= (leader_date + leader_flower_grace_period.days)
    end
  end

  # 检查领读人是否缺失工作
  def missing_leader_work?(date = Date.today)
    return false unless in_progress?

    schedule = reading_schedules.find_by(date: date)
    return false unless schedule&.daily_leader.present?

    # 检查是否缺失领读内容
    missing_content = !schedule.daily_leading.present?

    # 检查是否缺失小红花（如果是前一天或前两天的领读）
    missing_flowers = false
    if date <= Date.today && date >= Date.today - 2.days
      schedule_date = date
      flower_window_end = schedule_date + leader_flower_grace_period.days

      if Date.today <= flower_window_end
        # 还在小红花发放窗口内，检查是否已发放
        check_ins_count = schedule.check_ins.count
        flowers_count = schedule.flowers.count

        # 有打卡但没有足够的小红花（建议至少1朵）
        missing_flowers = check_ins_count > 0 && flowers_count == 0
      end
    end

    {
      schedule: schedule,
      missing_content: missing_content,
      missing_flowers: missing_flowers,
      leader: schedule.daily_leader,
      needs_backup: missing_content || missing_flowers
    }
  end

  # 获取需要补位的日程列表
  def schedules_need_backup
    return [] unless in_progress?

    # 检查最近3天的日程
    date_range = (Date.today - 1.day)..(Date.today + 1.day)
    schedules = reading_schedules.where(date: date_range).includes(:daily_leader, :daily_leading, :flowers, :check_ins)

    backup_needed = []

    schedules.each do |schedule|
      # 检查领读内容是否缺失
      content_missing = schedule.daily_leader.present? && !schedule.daily_leading.present?

      # 检查小红花是否缺失
      flowers_missing = false
      if schedule.date <= Date.today && schedule.check_ins.any?
        # 已经有打卡但没有小红花
        flowers_missing = schedule.flowers.empty?
      end

      if content_missing || flowers_missing
        backup_needed << {
          schedule: schedule,
          date: schedule.date,
          day_number: schedule.day_number,
          leader: schedule.daily_leader,
          missing_content: content_missing,
          missing_flowers: flowers_missing,
          content_deadline: schedule.date,
          flowers_deadline: schedule.date + leader_flower_grace_period.days
        }
      end
    end

    backup_needed
  end

  # 获取领读人权限窗口配置（可配置化）
  def leader_permission_window
    {
      content_publish_days_before: 1,    # 提前1天可以发布内容
      content_publish_days_after: 0,     # 当天后不能发布内容
      flower_give_days_before: 0,        # 当天前不能发小红花
      flower_give_days_after: 1          # 当天后1天可以发小红花
    }
  end

  # 统一的枚举访问方法 - 公有方法供Service使用
  def status_symbol
    status.to_sym
  end

  def approval_status_symbol
    approval_status.to_sym
  end

  def leader_assignment_type_symbol
    leader_assignment_type.to_sym
  end

  # 设置时也接受符号（可选，用于一致性）
  def status_symbol=(value)
    self.status = value.to_s
  end

  def approval_status_symbol=(value)
    self.approval_status = value.to_s
  end

  def leader_assignment_type_symbol=(value)
    self.leader_assignment_type = value.to_s
  end

  # 状态方法
  def can_start?
    enrolling? && start_date <= Date.current && enough_participants?
  end

  def can_enroll?
    enrolling? && (enrollment_deadline.blank? || enrollment_deadline > Time.current) && !max_participants_reached?
  end

  # 报名相关辅助方法
  def enrollment_error_message
    return "活动不在报名状态" unless enrolling?
    return "报名已截止" if enrollment_deadline.present? && enrollment_deadline <= Time.current
    return "活动人数已满" if max_participants_reached?
    return "活动尚未批准" unless approved?
    "无法报名"
  end

  def user_enrolled?(user)
    return false unless user
    event_enrollments.where(user: user, status: 'enrolled').exists?
  end

  def user_enrollment(user)
    return nil unless user
    event_enrollments.find_by(user: user)
  end

  def enrollment_statistics
    enrollments = event_enrollments.includes(:user)

    {
      total_enrollments: enrollments.count,
      active_enrollments: enrollments.where(status: 'enrolled').count,
      completed_enrollments: enrollments.where(status: 'completed').count,
      cancelled_enrollments: enrollments.where(status: 'cancelled').count,
      participants_count: enrollments.where(enrollment_type: 'participant').count,
      observers_count: enrollments.where(enrollment_type: 'observer').count,
      total_fees_collected: enrollments.sum(:fee_paid_amount),
      total_refunds_processed: enrollments.sum(:fee_refund_amount),
      enrollment_rate: calculate_enrollment_rate,
      completion_rate: calculate_overall_completion_rate(enrollments)
    }
  end

  def start!
    return false unless can_start?

    ActiveRecord::Base.transaction do
      update!(status: :in_progress)

      # 生成阅读计划（如果还没有）
      generate_reading_schedules if reading_schedules.empty?

      # 分配领读人
      assign_daily_leaders! if leader_assignment_type != 'disabled'

      true
    end
  end

  def complete!
    return false unless can_complete?

    ActiveRecord::Base.transaction do
      update!(status: :completed)

      # 处理所有未完成的报名
      event_enrollments.where(status: 'enrolled').each do |enrollment|
        enrollment.update_completion_rate!
      end

      # 生成完成证书
      generate_completion_certificates

      true
    end
  end

  def can_complete?
    in_progress? && end_date < Date.current
  end

  def max_participants_reached?
    event_enrollments.enrolled.count >= max_participants
  end

  def enough_participants?
    event_enrollments.enrolled.count >= min_participants
  end

  def participants_count
    # 使用缓存来避免重复查询
    @participants_count ||= event_enrollments.enrolled.count
  end

  # 类方法：批量计算多个活动的参与者数量（用于优化列表查询）
  def self.batch_participants_counts(events)
    return {} if events.empty?

    event_ids = events.map(&:id)
    enrollment_counts = EventEnrollment.where(reading_event_id: event_ids, status: 'enrolled')
                                            .group(:reading_event_id)
                                            .count

    events.map { |event| [event.id, enrollment_counts[event.id] || 0] }.to_h
  end

  def available_spots
    max_participants - participants_count
  end

  # 统计方法
  def completion_statistics
    enrollments = event_enrollments.includes(:user)

    {
      total_participants: enrollments.count,
      completed_participants: enrollments.where('completion_rate >= ?', completion_standard).count,
      average_completion_rate: enrollments.average(:completion_rate)&.round(2) || 0,
      total_check_ins: enrollments.sum(:check_ins_count),
      total_flowers: enrollments.sum(:flowers_received_count)
    }
  end

  # 费用计算方法
  def calculate_leader_reward
    return 0 if fee_type == 'free'

    if fee_type == 'deposit'
      fee_amount * (leader_reward_percentage / 100.0) * participants_count
    else # paid
      fee_amount * participants_count
    end
  end

  def calculate_deposit_pool
    return 0 if fee_type != 'deposit'

    total_fees = fee_amount * participants_count
    leader_reward = calculate_leader_reward
    total_fees - leader_reward
  end

  # 验证活动是否满足审批条件（公开方法供Service使用）
  def validate_event_for_approval
    errors = []

    # 检查基本信息
    errors << "活动标题不能为空" if title.blank?
    errors << "活动描述不能为空" if description.blank?
    errors << "书籍名称不能为空" if book_name.blank?

    # 检查日期设置
    errors << "开始日期不能为空" if start_date.blank?
    errors << "结束日期不能为空" if end_date.blank?
    errors << "开始日期必须在今天之后" if start_date <= Date.today

    # 检查人数设置
    errors << "最大参与人数必须大于0" if max_participants.nil? || max_participants <= 0
    errors << "最小参与人数不能大于最大参与人数" if min_participants > max_participants

    # 检查费用设置（如果是收费活动）
    if fee_type != 'free'
      errors << "收费活动必须设置费用金额" if fee_amount.nil? || fee_amount <= 0
      errors << "收费活动必须设置领读人奖励比例" if leader_reward_percentage.nil?
    end

    # 检查阅读计划
    if reading_schedules.empty?
      errors << "必须设置阅读计划"
    end

    # 检查特定活动模式的特殊要求
    case activity_mode
    when 'video_conference'
      errors << "视频会议活动必须设置会议链接" if meeting_link.blank?
    when 'offline_meeting'
      errors << "线下活动必须设置活动地点" if location.blank?
    end

    {
      valid: errors.empty?,
      errors: errors
    }
  end

  # 小红花统计
  def flowers_count
    Flower.joins(check_in: :event_enrollment)
          .where(event_enrollments: { reading_event_id: id })
          .count
  end

  def flowers_given_count
    Flower.joins(check_in: :event_enrollment)
          .where(event_enrollments: { reading_event_id: id })
          .count
  end

  # 小红花配额
  has_many :flower_quotas, dependent: :destroy

  # 小红花证书
  has_many :flower_certificates, dependent: :destroy

  # 获取活动中的小红花排行榜（前三名）
  def flower_top_three
    flower_stats = Flower.joins(:recipient)
                          .joins(check_in: :event_enrollment)
                          .where(event_enrollments: { reading_event_id: id })
                          .group('recipients.id')
                          .sum(:amount)

    flower_stats.sort_by { |user_id, flowers| -flowers }
               .first(3)
               .map.with_index(1) { |(user_id, flowers), index| [User.find(user_id), flowers, index] }
  end

  # 检查用户是否有剩余配额
  def user_has_remaining_flower_quota?(user)
    return false unless participants.include?(user)

    quota = FlowerQuota.get_or_create_quota(user, self)
    quota.can_give_flower?
  end

  # 活动结束时自动生成证书
  def generate_flower_certificates_if_completed
    return unless status == 'completed'

    FlowerCertificate.generate_top_three_certificates(self)
  end

  # 检查用户是否在活动中有剩余小红花配额
  def user_has_remaining_flower_quota?(user)
    return false unless participants.include?(user)

    quota = FlowerQuota.get_or_create_quota(user, self)
    quota.can_give_flower?
  end

  # 获取用户在活动中的配额信息
  def user_flower_quota_info(user)
    return nil unless participants.include?(user)

    FlowerIncentiveService.get_user_quota_info(user, self)
  end

  # 获取活动的小红花激励统计
  def flower_incentive_statistics
    return { error: '活动未结束' } unless status == 'completed'

    certificates = FlowerCertificate.for_event(self).ranked
    total_flowers_given = Flower.joins(:recipient)
                                .joins(check_in: :event_enrollment)
                                .where(event_enrollments: { reading_event_id: id })
                                .sum(:amount)

    {
      event: title,
      status: status,
      total_participants: participants.count,
      total_flowers_given: total_flowers_given,
      certificates_generated: certificates.count,
      top_three_winners: certificates.map do |cert|
        {
          rank: cert.rank_display,
          user: cert.user.as_json_for_api,
          total_flowers: cert.total_flowers,
          honor_level: cert.honor_level,
          certificate_id: cert.certificate_id
        }
      end,
      generated_at: certificates.first&.created_at
    }
  end

  # 活动结束时生成小红花总结和证书
  def finalize_flower_incentives
    return { error: '活动未结束' } unless status == 'completed'
    return { error: '活动没有参与者' } if participants.empty?

    # 生成证书
    result = FlowerIncentiveService.finalize_event_flower_certificates(self)

    # 生成活动总结
    summary = {
      event: title,
      duration: "#{start_date} 至 #{end_date}",
      participants_count: participants.count,
      certificates_generated: result[:certificates]&.count || 0,
      total_flowers_given: flowers_count,
      top_three: result[:certificates]&.map do |cert|
        {
          rank: cert[:rank_display],
          user: cert[:user],
          total_flowers: cert[:total_flowers]
        }
      end
    }

    {
      success: true,
      summary: summary,
      certificates: result[:certificates]
    }
  end

  # API响应格式化
  def as_json_for_api(options = {})
    base_data = {
      id: id,
      title: title,
      book_name: book_name,
      book_cover_url: book_cover_url,
      description: description,
      start_date: start_date,
      end_date: end_date,
      max_participants: max_participants,
      min_participants: min_participants,
      fee_type: fee_type,
      fee_amount: fee_amount,
      leader_reward_percentage: leader_reward_percentage,
      completion_standard: completion_standard,
      activity_mode: activity_mode,
      weekend_rest: weekend_rest,
      leader_assignment_type: leader_assignment_type,
      status: status,
      approval_status: approval_status,
      created_at: created_at,
      updated_at: updated_at
    }

    # 可选包含关联数据
    if options[:include_leader]
      base_data[:leader] = leader&.as_json_for_api
    end

    if options[:include_participants]
      base_data[:participants] = participants.map(&:as_json_for_api)
    end

    if options[:include_statistics]
      base_data[:statistics] = completion_statistics
      base_data[:enrollment_statistics] = enrollment_statistics
    end

    if options[:include_schedules]
      base_data[:reading_schedules] = reading_schedules.map do |schedule|
        {
          id: schedule.id,
          day_number: schedule.day_number,
          date: schedule.date,
          reading_progress: schedule.reading_progress
        }
      end
    end

    base_data
  end

  private

  def calculate_enrollment_rate
    return 0 if max_participants == 0
    (event_enrollments.enrolled.count.to_f / max_participants * 100).round(2)
  end

  def calculate_overall_completion_rate(enrollments)
    return 0 if enrollments.empty?
    (enrollments.average(:completion_rate) || 0).round(2)
  end

  def generate_reading_schedules
    return unless start_date && end_date

    (start_date..end_date).each_with_index do |date, index|
      next if weekend_rest && (date.saturday? || date.sunday?)

      reading_schedules.create!(
        day_number: index + 1,
        date: date,
        reading_pages: nil, # 可以根据需要设置默认阅读页数
        reading_content: nil
      )
    end
  end

  def generate_completion_certificates
    event_enrollments.where(status: 'completed').each do |enrollment|
      next unless enrollment.is_completed?

      # 生成完成证书
      ParticipationCertificate.generate_completion_certificate(enrollment)

      # 检查小红花排名并生成相应证书
      flower_rank = get_flower_rank(enrollment)
      if flower_rank && flower_rank <= 3
        ParticipationCertificate.generate_flower_certificate(enrollment, flower_rank)
      end
    end
  end

  def get_flower_rank(enrollment)
    return 0 if enrollment.flowers_received_count == 0

    rankings = event_enrollments
      .where('flowers_received_count > 0')
      .order(flowers_received_count: :desc)
      .pluck(:id)

    rankings.index(enrollment.id) + 1
  end

  private

  def leader_flower_grace_period
    leader_permission_window[:flower_give_days_after]
  end

  # 验证方法
  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "必须在开始日期之后")
    end
  end

  def enrollment_deadline_before_start_date
    return if enrollment_deadline.blank? || start_date.blank?

    if enrollment_deadline > start_date.to_time
      errors.add(:enrollment_deadline, "必须在活动开始日期之前")
    end
  end

  def min_participants_not_greater_than_max
    return if min_participants.blank? || max_participants.blank?

    if min_participants > max_participants
      errors.add(:min_participants, "不能大于最大参与人数")
    end
  end

  def can_be_enrolling?
    start_date > Date.current && approval_status == 'approved'
  end

  def generate_event_summary
    # 这里可以实现活动总结的生成逻辑
    # 比如统计小红花排名、完成率等
    puts "活动【#{title}】已完成！"
  end
end
