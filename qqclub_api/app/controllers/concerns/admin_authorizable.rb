# 管理员权限验证 concern
module AdminAuthorizable
  extend ActiveSupport::Concern

  # 检查是否是管理员或root用户
  def authenticate_admin!
    unless current_user&.any_admin?
      render json: {
        error: "需要管理员权限",
        details: {
          required_role: "admin 或 root",
          current_role: current_user&.role_display_name || "未登录"
        }
      }, status: :forbidden
    end
  end

  # 检查是否是root用户
  def authenticate_root!
    unless current_user&.root?
      render json: {
        error: "需要超级管理员权限",
        details: {
          required_role: "root",
          current_role: current_user&.role_display_name || "未登录"
        }
      }, status: :unauthorized
    end
  end

  # 检查用户是否有特定权限
  def authorize_permission!(permission)
    unless current_user&.has_permission?(permission)
      render json: {
        error: "权限不足",
        details: {
          required_permission: permission,
          current_role: current_user&.role_display_name || "未登录"
        }
      }, status: :forbidden
    end
  end

  # 检查是否有审批活动权限
  def authorize_event_approval!
    authorize_permission!(:approve_events)
  end

  # 检查是否有管理用户权限
  def authorize_user_management!
    authorize_permission!(:manage_users)
  end

  # 检查是否有查看管理面板权限
  def authorize_admin_panel!
    authorize_permission!(:view_admin_panel)
  end

  # 检查是否有系统管理权限
  def authorize_system_management!
    authorize_permission!(:manage_system)
  end

  private

  # 辅助方法：检查当前用户是否是管理员
  def current_user_admin?
    current_user&.any_admin?
  end

  # 辅助方法：检查当前用户是否是root
  def current_user_root?
    current_user&.root?
  end

  # 辅助方法：获取用户角色信息
  def user_role_info(user = current_user)
    return { role: "未登录", permissions: [] } unless user

    {
      role: user.role_display_name,
      permissions: user_permissions(user)
    }
  end

  # 辅助方法：获取用户权限列表
  def user_permissions(user)
    permissions = []
    permissions << "approve_events" if user.can_approve_events?
    permissions << "manage_users" if user.can_manage_users?
    permissions << "view_admin_panel" if user.can_view_admin_panel?
    permissions << "manage_system" if user.can_manage_system?
    permissions
  end
end