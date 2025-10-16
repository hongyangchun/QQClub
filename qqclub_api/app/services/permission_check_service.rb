# frozen_string_literal: true

# PermissionCheckService - 统一权限验证服务
# 整合各种权限检查逻辑，提供统一的权限验证接口
class PermissionCheckService < ApplicationService
  attr_reader :user, :resource, :action, :context

  def initialize(user:, resource:, action:, context: {})
    super()
    @user = user
    @resource = resource
    @action = action
    @context = context
  end

  # 主要调用方法
  def call
    handle_errors do
      return failure!("用户不能为空") unless user
      return failure!("资源不能为空") unless resource

      case action
      when :approve_events
        check_approve_events_permission
      when :manage_users
        check_manage_users_permission
      when :view_admin_panel
        check_view_admin_panel_permission
      when :manage_system
        check_manage_system_permission
      when :edit_post
        check_edit_post_permission
      when :hide_post
        check_hide_post_permission
      when :pin_post
        check_pin_post_permission
      when :manage_event
        check_manage_event_permission
      when :claim_leadership
        check_claim_leadership_permission
      when :complete_event
        check_complete_event_permission
      else
        failure!("不支持的权限检查: #{action}")
      end
    end
  end

  # 类方法：快速权限检查
  def self.can?(user, resource, action, context = {})
    new(user: user, resource: resource, action: action, context: context).call.success?
  end

  private

  # 检查活动审批权限
  def check_approve_events_permission
    if user.can_approve_events?
      success!
    else
      failure!("用户 #{user.nickname} 没有审批活动的权限")
    end
  end

  # 检查用户管理权限
  def check_manage_users_permission
    if user.can_manage_users?
      success!
    else
      failure!("用户 #{user.nickname} 没有管理用户的权限")
    end
  end

  # 检查管理面板查看权限
  def check_view_admin_panel_permission
    if user.can_view_admin_panel?
      success!
    else
      failure!("用户 #{user.nickname} 没有查看管理面板的权限")
    end
  end

  # 检查系统管理权限
  def check_manage_system_permission
    if user.can_manage_system?
      success!
    else
      failure!("用户 #{user.nickname} 没有系统管理权限")
    end
  end

  # 检查帖子编辑权限
  def check_edit_post_permission
    if resource.is_a?(Post)
      if resource.can_edit?(user)
        success!
      else
        failure!("用户 #{user.nickname} 没有编辑此帖子的权限")
      end
    else
      failure!("资源类型不正确，期望Post")
    end
  end

  # 检查帖子隐藏权限
  def check_hide_post_permission
    if resource.is_a?(Post)
      if resource.can_hide?(user)
        success!
      else
        failure!("用户 #{user.nickname} 没有隐藏此帖子的权限")
      end
    else
      failure!("资源类型不正确，期望Post")
    end
  end

  # 检查帖子置顶权限
  def check_pin_post_permission
    if resource.is_a?(Post)
      if resource.can_pin?(user)
        success!
      else
        failure!("用户 #{user.nickname} 没有置顶此帖子的权限")
      end
    else
      failure!("资源类型不正确，期望Post")
    end
  end

  # 检查活动管理权限
  def check_manage_event_permission
    if resource.is_a?(ReadingEvent)
      # 活动创建者或管理员可以管理活动
      if resource.leader_id == user.id || user.any_admin?
        success!
      else
        failure!("用户 #{user.nickname} 没有管理此活动的权限")
      end
    else
      failure!("资源类型不正确，期望ReadingEvent")
    end
  end

  # 检查领读报名权限
  def check_claim_leadership_permission
    if resource.is_a?(ReadingEvent) && context[:schedule]
      schedule = context[:schedule]

      # 检查是否是自由报名模式
      unless resource.leader_assignment_type == 'voluntary'
        return failure!("该活动不支持自由报名领读")
      end

      # 检查是否已报名该活动
      unless user.enrollments.exists?(reading_event: resource)
        return failure!("请先报名该活动")
      end

      # 检查是否已有领读人
      if schedule.daily_leader.present?
        return failure!("该日已有领读人")
      end

      # 检查领读次数限制
      leadership_count = resource.reading_schedules.where(daily_leader: user).count
      if leadership_count >= 3
        return failure!("领读次数已达上限")
      end

      success!
    else
      failure!("资源类型或上下文不正确，期望ReadingEvent和schedule")
    end
  end

  # 检查活动完成权限
  def check_complete_event_permission
    if resource.is_a?(ReadingEvent)
      # 只有活动小组长可以结束活动
      if resource.current_leader?(user)
        success!
      else
        failure!("只有活动小组长可以结束活动")
      end
    else
      failure!("资源类型不正确，期望ReadingEvent")
    end
  end
end