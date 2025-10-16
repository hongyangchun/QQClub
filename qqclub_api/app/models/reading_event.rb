class ReadingEvent < ApplicationRecord
  # 关联
  belongs_to :leader, class_name: "User"
  belongs_to :approved_by, class_name: "User", optional: true  # 审批人
  has_many :enrollments, dependent: :destroy
  has_many :participants, through: :enrollments, source: :user
  has_many :reading_schedules, dependent: :destroy

  # 验证
  validates :title, presence: true
  validates :book_name, presence: true
  validates :start_date, :end_date, presence: true
  validates :max_participants, numericality: { greater_than: 0 }
  validates :enrollment_fee, numericality: { greater_than_or_equal_to: 0 }
  validate :end_date_after_start_date

  # 枚举：状态
  enum :status, { draft: 0, enrolling: 1, in_progress: 2, completed: 3 }

  # 枚举：审批状态
  enum :approval_status, { pending: 0, approved: 1, rejected: 2 }

  # 枚举：领读人分配类型
  enum :leader_assignment_type, { voluntary: 0, random: 1 }

  # 计算方法
  def service_fee
    enrollment_fee * 0.2
  end

  def deposit
    enrollment_fee * 0.8
  end

  def days_count
    return 0 unless start_date && end_date
    (end_date - start_date).to_i + 1
  end

  # 审批相关方法
  def approve!(admin_user)
    update!(
      approval_status: :approved,
      approved_by: admin_user,
      approved_at: Time.current
    )
  end

  def reject!(admin_user, reason = nil)
    update!(
      approval_status: :rejected,
      approved_by: admin_user,
      approved_at: Time.current
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

  # 领读人分配方法
  def assign_daily_leaders!
    return unless approved? && reading_schedules.any?

    if leader_assignment_type == 'random'
      assign_random_leaders!
    end
    # voluntary 模式下，用户需要自己报名领读
  end

  def assign_random_leaders!
    participants = enrollments.includes(:user).where(role: :participant).map(&:user)
    return if participants.empty?

    schedules = reading_schedules.order(:day_number)
    schedules.each_with_index do |schedule, index|
      leader = participants[index % participants.length]
      schedule.update!(daily_leader: leader)
    end
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

  private

  def leader_flower_grace_period
    leader_permission_window[:flower_give_days_after]
  end

  private

  def generate_event_summary
    # 这里可以实现活动总结的生成逻辑
    # 比如统计小红花排名、完成率等
    puts "活动【#{title}】已完成！"
  end

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date < start_date
      errors.add(:end_date, "必须在开始日期之后")
    end
  end
end
