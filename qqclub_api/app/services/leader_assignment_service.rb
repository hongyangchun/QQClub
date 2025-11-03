# frozen_string_literal: true

# LeaderAssignmentService - 领读人分配管理服务
# 负责多种分配算法、权限管理、工作统计、补位机制等业务逻辑
class LeaderAssignmentService < ApplicationService
  attr_reader :event, :user, :schedule, :action, :assignment_options

  def initialize(event:, user: nil, schedule: nil, action: nil, assignment_options: {})
    super()
    @event = event
    @user = user
    @schedule = schedule
    @action = action
    @assignment_options = assignment_options.with_indifferent_access
  end

  # 主要调用方法
  def call
    handle_errors do
      case action
      when :claim_leadership
        claim_leadership
      when :auto_assign
        auto_assign_leaders
      when :backup_assign
        backup_assignment
      when :reassign
        reassign_leader
      when :get_statistics
        get_assignment_statistics
      when :check_permissions
        check_leader_permissions
      else
        failure!("不支持的操作: #{action}")
      end
    end

    self
  end

  # 类方法：自由报名领读
  def self.claim_leadership!(event, user, schedule)
    new(event: event, user: user, schedule: schedule, action: :claim_leadership).call
  end

  # 类方法：自动分配领读人
  def self.auto_assign_leaders!(event, assignment_type: nil, options: {})
    new(event: event, action: :auto_assign, assignment_options: { assignment_type: assignment_type }.merge(options)).call
  end

  # 类方法：补位分配
  def self.backup_assignment!(event, schedule, backup_leader)
    new(event: event, schedule: schedule, user: backup_leader, action: :backup_assign).call
  end

  # 类方法：重新分配领读人
  def self.reassign_leader!(event, schedule, new_leader)
    new(event: event, schedule: schedule, user: new_leader, action: :reassign).call
  end

  # 类方法：获取分配统计
  def self.assignment_statistics(event)
    new(event: event, action: :get_statistics).call
  end

  # 类方法：检查领读权限
  def self.check_permissions(event, user, schedule = nil)
    new(event: event, user: user, schedule: schedule, action: :check_permissions).call
  end

  private

  # 自由报名领读
  def claim_leadership
    # 检查是否是自由报名模式
    unless event.leader_assignment_type == 'voluntary'
      return failure!("该活动不支持自由报名领读")
    end

    # 检查是否已报名该活动
    unless user.event_enrollments.exists?(reading_event: event)
      return failure!("请先报名该活动")
    end

    # 检查是否已有领读人
    if schedule.daily_leader.present?
      return failure!("该日已有领读人")
    end

    # 检查领读次数限制
    leadership_count = event.reading_schedules.where(daily_leader: user).count
    if leadership_count >= 3
      return failure!("领读次数已达上限")
    end

    # 分配领读人
    schedule.update!(daily_leader: user)

    success!({
      message: "领读报名成功",
      schedule_data: {
        id: schedule.id,
        day_number: schedule.day_number,
        date: schedule.date,
        leader: {
          id: user.id,
          nickname: user.nickname,
          avatar_url: user.avatar_url
        }
      }
    })
  end

  # 自动分配领读人（支持多种算法）
  def auto_assign_leaders
    return failure!("活动未审批或没有日程安排") unless event.approved? && event.reading_schedules.any?

    assignment_type = @assignment_options[:assignment_type] || event.leader_assignment_type

    case assignment_type.to_sym
    when :random
      assign_random_leaders!
    when :balanced
      assign_balanced_leaders!
    when :rotation
      assign_rotation_leaders!
    when :voluntary
      assign_voluntary_leaders!
    else
      return failure!("不支持的分配方式: #{assignment_type}")
    end

    success!({
      message: "领读人分配完成",
      assignment_type: assignment_type,
      assigned_count: event.reading_schedules.where.not(daily_leader: nil).count
    })
  end

  # 随机分配领读人算法
  def assign_random_leaders!
    participants = get_available_participants
    return failure!("没有参与者可供分配") if participants.empty?

    schedules = event.reading_schedules.order(:day_number)
    schedules.each_with_index do |schedule, index|
      leader = participants[index % participants.length]
      schedule.update!(daily_leader: leader)
    end
  end

  # 平衡分配算法（基于历史工作量）
  def assign_balanced_leaders!
    participants = get_available_participants
    return failure!("没有参与者可供分配") if participants.empty?

    # 计算历史工作量
    leader_workloads = calculate_leader_workloads(participants)

    schedules = event.reading_schedules.order(:day_number)
    schedules.each do |schedule|
      # 选择工作量最小的参与者
      least_busy_leader = leader_workloads.min_by { |_, workload| workload }.first
      schedule.update!(daily_leader: least_busy_leader)

      # 更新工作量
      leader_workloads[least_busy_leader] += 1
    end
  end

  # 轮换分配算法（确保每个人都能领读，避免连续领读）
  def assign_rotation_leaders!
    participants = get_available_participants
    return failure!("没有参与者可供分配") if participants.empty?

    schedules = event.reading_schedules.order(:day_number)
    rotation_queue = participants.dup
    last_leader = nil

    schedules.each do |schedule|
      # 避免连续分配给同一个人
      if rotation_queue.first == last_leader && rotation_queue.size > 1
        rotation_queue.rotate!
      end

      leader = rotation_queue.first
      schedule.update!(daily_leader: leader)
      last_leader = leader

      # 将领过的人移到队列末尾
      rotation_queue.rotate!
    end
  end

  # 自愿分配算法（基于自愿报名）
  def assign_voluntary_leaders!
    volunteer_assignments = @assignment_options[:volunteer_assignments] || {}
    schedules = event.reading_schedules.order(:day_number)

    assigned_count = 0
    schedules.each do |schedule|
      if volunteer_assignments[schedule.id]
        user_id = volunteer_assignments[schedule.id]
        user = User.find_by(id: user_id)

        if user && can_be_leader?(user)
          schedule.update!(daily_leader: user)
          assigned_count += 1
        end
      end
    end

    success!({
      message: "自愿分配完成",
      assigned_count: assigned_count
    })
  end

  # 补位分配机制
  def backup_assignment
    return failure!("补位需要指定日程和补位人") unless schedule && user

    # 检查补位权限
    unless event.leader == user
      return failure!("只有活动创建者可以进行补位分配")
    end

    # 检查日程是否需要补位
    unless schedule_needs_backup?(schedule)
      return failure!("该日程不需要补位")
    end

    ActiveRecord::Base.transaction do
      schedule.update!(daily_leader: user)

      # 记录补位操作
      log_backup_assignment(schedule, user)
    end

    success!({
      message: "补位分配成功",
      schedule: schedule_info(schedule),
      backup_leader: user_info(user)
    })
  end

  # 重新分配领读人
  def reassign_leader
    return failure!("需要指定日程和新领读人") unless schedule && user

    # 检查权限
    unless can_reassign_leader?(user)
      return failure!("权限不足")
    end

    old_leader = schedule.daily_leader
    ActiveRecord::Base.transaction do
      schedule.update!(daily_leader: user)

      # 记录重新分配操作
      log_reassignment(schedule, old_leader, user)
    end

    success!({
      message: "领读人重新分配成功",
      schedule: schedule_info(schedule),
      old_leader: old_leader ? user_info(old_leader) : nil,
      new_leader: user_info(user)
    })
  end

  # 获取分配统计信息
  def get_assignment_statistics
    schedules = event.reading_schedules.includes(:daily_leader, :daily_leading)

    total_schedules = schedules.count
    assigned_schedules = schedules.where.not(daily_leader: nil).count
    leaders = schedules.where.not(daily_leader: nil).pluck(:daily_leader_id).uniq

    stats = {
      total_schedules: total_schedules,
      assigned_schedules: assigned_schedules,
      unassigned_schedules: total_schedules - assigned_schedules,
      unique_leaders: leaders.count,
      assignment_rate: total_schedules > 0 ? (assigned_schedules.to_f / total_schedules * 100).round(2) : 0,
      leader_workload: calculate_leader_workload_statistics(schedules),
      backup_needed: backup_needed_schedules.size,
      content_completion_rate: calculate_content_completion_rate(schedules)
    }

    success!(stats)
  end

  # 检查领读权限
  def check_leader_permissions
    return success!({ can_view: false, message: "用户不存在" }) unless user
    return success!({ can_view: false, message: "用户未报名活动" }) unless user.enrolled?(event)

    permissions = {
      can_view: true,
      can_claim_leadership: can_claim_leadership?,
      can_be_assigned: can_be_assigned_as_leader?,
      can_backup: can_backup_assignment?,
      current_schedules: user_leading_schedules,
      permission_window: get_permission_window_info
    }

    success!(permissions)
  end

  private

  # 辅助方法
  def get_available_participants
    event.event_enrollments.includes(:user).where(status: 'enrolled').map(&:user).compact
  end

  def can_be_leader?(user)
    return false unless user
    return false unless user.event_enrollments.exists?(reading_event: event)
    return false unless event.event_enrollments.find_by(user: user)&.status == 'enrolled'

    true
  end

  def can_claim_leadership?
    return false unless event.leader_assignment_type == 'voluntary'
    return false unless schedule
    return false if schedule.daily_leader.present?

    # 检查领读次数限制
    leadership_count = event.reading_schedules.where(daily_leader: user).count
    leadership_count < (@assignment_options[:max_leadership_count] || 3)
  end

  def can_be_assigned_as_leader?
    can_be_leader?(user) && event.in_progress?
  end

  def can_backup_assignment?
    event.leader == user
  end

  def can_reassign_leader?(user)
    # 活动创建者可以重新分配
    return true if event.leader == user

    # 或者在权限窗口内的领读人
    event.current_daily_leader?(user, schedule)
  end

  def schedule_needs_backup?(schedule)
    # 检查是否缺少领读人
    return true unless schedule.daily_leader.present?

    # 检查是否缺少领读内容
    if schedule.daily_leader.present? && !schedule.daily_leading.present?
      return true
    end

    # 检查是否缺少小红花（如果有打卡的话）
    if schedule.date <= Date.today && schedule.check_ins.any? && schedule.flowers.empty?
      return true
    end

    false
  end

  def calculate_leader_workloads(participants)
    workloads = participants.index_by(&:id).transform_values { 0 }

    # 可以扩展为查询历史工作量
    # 目前简化处理，所有参与者初始工作量为0

    workloads
  end

  def calculate_leader_workload_statistics(schedules)
    workload = {}

    schedules.where.not(daily_leader: nil).each do |schedule|
      leader_id = schedule.daily_leader_id
      workload[leader_id] ||= {
        nickname: schedule.daily_leader.nickname,
        assigned_count: 0,
        content_completed: 0,
        flowers_given: 0
      }

      workload[leader_id][:assigned_count] += 1
      workload[leader_id][:content_completed] += 1 if schedule.daily_leading.present?
      workload[leader_id][:flowers_given] += schedule.flowers.count
    end

    workload.values
  end

  def calculate_content_completion_rate(schedules)
    return 0 if schedules.empty?

    completed_count = schedules.joins(:daily_leading).count
    (completed_count.to_f / schedules.count * 100).round(2)
  end

  def backup_needed_schedules
    event.schedules_need_backup || []
  end

  def user_leading_schedules
    return [] unless user

    event.reading_schedules
      .where(daily_leader: user)
      .includes(:daily_leading, :flowers, :check_ins)
      .map do |schedule|
        {
          id: schedule.id,
          day_number: schedule.day_number,
          date: schedule.date,
          has_content: schedule.daily_leading.present?,
          flowers_count: schedule.flowers.count,
          check_ins_count: schedule.check_ins.count
        }
      end
  end

  def get_permission_window_info
    return {} unless user && schedule

    {
      can_publish_content: event.can_publish_leading_content?(user, schedule),
      can_give_flowers: event.can_give_flowers?(user, schedule),
      permission_deadline: schedule.date + 1.day
    }
  end

  def schedule_info(schedule)
    {
      id: schedule.id,
      day_number: schedule.day_number,
      date: schedule.date,
      reading_progress: schedule.reading_progress
    }
  end

  def user_info(user)
    {
      id: user.id,
      nickname: user.nickname,
      avatar_url: user.avatar_url
    }
  end

  def log_backup_assignment(schedule, backup_leader)
    Rails.logger.info "补位分配: 活动 #{event.id}, 日程 #{schedule.id}, 补位人 #{backup_leader.nickname}"
  end

  def log_reassignment(schedule, old_leader, new_leader)
    Rails.logger.info "重新分配: 活动 #{event.id}, 日程 #{schedule.id}, 原领读人 #{old_leader&.nickname}, 新领读人 #{new_leader.nickname}"
  end
end