# frozen_string_literal: true

# EventManagementService - 活动生命周期管理服务
# 负责活动的创建、审批、拒绝、完成等核心业务逻辑
class EventManagementService < ApplicationService
  attr_reader :event, :admin_user, :action

  def initialize(event:, admin_user: nil, action: nil)
    super()
    @event = event
    @admin_user = admin_user
    @action = action
  end

  # 主要调用方法
  def call
    handle_errors do
      case action
      when :approve
        approve_event
      when :reject
        reject_event
      when :complete
        complete_event
      else
        failure!("不支持的操作: #{action}")
      end
    end
    self  # 返回service实例
  end

  # 类方法：审批活动
  def self.approve_event!(event, admin_user)
    new(event: event, admin_user: admin_user, action: :approve).call
  end

  # 类方法：拒绝活动
  def self.reject_event!(event, admin_user)
    new(event: event, admin_user: admin_user, action: :reject).call
  end

  # 类方法：完成活动
  def self.complete_event!(event, current_user)
    new(event: event, admin_user: current_user, action: :complete).call
  end

  private

  # 审批活动
  def approve_event
    return failure!("管理员用户不能为空") unless admin_user

    # 检查管理员权限
    unless admin_user.can_approve_events?
      return failure!("用户 #{admin_user.nickname} 没有审批权限")
    end

    # 检查活动状态
    unless event.pending_approval?
      return failure!("只能审批待审批的活动")
    end

    # 执行审批
    event.transaction do
      event.approve!(admin_user)

      # 如果是随机分配模式且有足够参与者，自动分配领读人
      if event.leader_assignment_type == 'random' && event.enrollments.count >= 3
        event.assign_daily_leaders!
      end
    end

    success!({
      message: "活动审批通过",
      event_data: {
        'id' => event.id,
        'title' => event.title,
        'status' => event.status_symbol,
        'approval_status' => event.approval_status_symbol,
        'approved_by' => admin_user.nickname,
        'approved_at' => event.approved_at
      }
    })
  end

  # 拒绝活动
  def reject_event
    return failure!("管理员用户不能为空") unless admin_user

    # 检查管理员权限
    unless admin_user.can_approve_events?
      return failure!("用户 #{admin_user.nickname} 没有审批权限")
    end

    # 检查活动状态
    unless event.pending_approval?
      return failure!("只能拒绝待审批的活动")
    end

    # 执行拒绝
    event.reject!(admin_user)

    success!({
      message: "活动已被拒绝",
      event_data: {
        'id' => event.id,
        'title' => event.title,
        'status' => event.status_symbol,
        'approval_status' => event.approval_status_symbol,
        'rejected_by' => admin_user.nickname,
        'rejected_at' => event.approved_at
      }
    })
  end

  # 完成活动
  def complete_event
    # 检查活动状态（先检查状态，再检查权限）
    if event.completed?
      return failure!("活动已经结束")
    end

    # 检查用户权限 - 只有活动小组长可以结束活动
    unless event.current_leader?(admin_user)
      return failure!("只有活动小组长可以结束活动")
    end

    # 执行活动完成
    event.complete_event!

    success!({
      message: "活动已成功结束",
      event_data: {
        'id' => event.id,
        'title' => event.title,
        'status' => event.status_symbol,
        'completed_at' => Time.current
      }
    })
  end
end