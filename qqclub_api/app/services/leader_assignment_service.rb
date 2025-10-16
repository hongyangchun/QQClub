# frozen_string_literal: true

# LeaderAssignmentService - 领读人分配管理服务
# 负责随机分配领读人、自由报名领读等业务逻辑
class LeaderAssignmentService < ApplicationService
  attr_reader :event, :user, :schedule, :action

  def initialize(event:, user: nil, schedule: nil, action: nil)
    super()
    @event = event
    @user = user
    @schedule = schedule
    @action = action
  end

  # 主要调用方法
  def call
    handle_errors do
      case action
      when :claim_leadership
        claim_leadership
      when :auto_assign
        auto_assign_leaders
      else
        failure!("不支持的操作: #{action}")
      end
    end
  end

  # 类方法：自由报名领读
  def self.claim_leadership!(event, user, schedule)
    new(event: event, user: user, schedule: schedule, action: :claim_leadership).call
  end

  # 类方法：自动分配领读人
  def self.auto_assign_leaders!(event)
    new(event: event, action: :auto_assign).call
  end

  private

  # 自由报名领读
  def claim_leadership
    # 检查是否是自由报名模式
    unless event.leader_assignment_type == 'voluntary'
      return failure!("该活动不支持自由报名领读")
    end

    # 检查是否已报名该活动
    unless user.enrollments.exists?(reading_event: event)
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

  # 自动分配领读人
  def auto_assign_leaders
    return failure!("活动未审批或没有日程安排") unless event.approved? && event.reading_schedules.any?

    if event.leader_assignment_type == 'random'
      assign_random_leaders!
    else
      return failure!("该活动不支持自动分配")
    end

    success!({
      message: "领读人分配完成",
      assigned_count: event.reading_schedules.where.not(daily_leader: nil).count
    })
  end

  # 随机分配领读人算法
  def assign_random_leaders!
    participants = event.enrollments.includes(:user).where(role: :participant).map(&:user)
    return failure!("没有参与者可供分配") if participants.empty?

    schedules = event.reading_schedules.order(:day_number)
    schedules.each_with_index do |schedule, index|
      leader = participants[index % participants.length]
      schedule.update!(daily_leader: leader)
    end
  end
end