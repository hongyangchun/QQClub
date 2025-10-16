module Api
  module Admin
    class AdminController < ApplicationController
    include AdminAuthorizable
    before_action :authenticate_admin!

    # GET /api/admin/dashboard
    def dashboard
      render json: {
        current_user: {
          id: current_user.id,
          nickname: current_user.nickname,
          role: current_user.role_display_name,
          permissions: current_user_permissions
        },
        system_stats: {
          total_users: User.count,
          total_posts: Post.count,
          visible_posts: Post.visible.count,
          total_events: ReadingEvent.count,
          pending_events: ReadingEvent.where(approval_status: :pending).count,
          active_events: ReadingEvent.where(status: :in_progress).count,
          admin_count: User.where(role: :admin).count,
          root_count: User.where(role: :root).count
        },
        available_actions: admin_available_actions
      }
    end

    # GET /api/admin/users
    def users
      authenticate_root!  # 只有root可以查看所有用户

      users = User.select(:id, :nickname, :role, :created_at, :wx_openid)
                   .order(created_at: :desc)

      render json: {
        users: users.map { |user|
          {
            id: user.id,
            nickname: user.nickname,
            role: user.role_display_name,
            role_value: user.role,
            created_at: user.created_at,
            permissions: user_permissions_for(user)
          }
        },
        summary: {
          total: users.count,
          by_role: {
            user: users.select(&:user?).count,
            admin: users.select(&:admin?).count,
            root: users.select(&:root?).count
          }
        }
      }
    end

    # PUT /api/admin/users/:id/promote_admin
    def promote_user_to_admin
      authenticate_root!  # 只有root可以提升管理员

      user = User.find(params[:id])
      if user.root?
        return render json: { error: "不能提升超级管理员" }, status: :unprocessable_entity
      end

      if user.update!(role: :admin)
        render json: {
          message: "用户已提升为管理员",
          user: {
            id: user.id,
            nickname: user.nickname,
            new_role: user.role_display_name
          }
        }
      else
        render json: { error: "提升失败" }, status: :unprocessable_entity
      end
    end

    # PUT /api/admin/users/:id/demote
    def demote_user
      authenticate_root!  # 只有root可以降级用户

      user = User.find(params[:id])
      if user.root?
        return render json: { error: "不能降级超级管理员" }, status: :unprocessable_entity
      end

      if user.update!(role: :participant)
        render json: {
          message: "用户已降级为参与者",
          user: {
            id: user.id,
            nickname: user.nickname,
            new_role: user.role_display_name
          }
        }
      else
        render json: { error: "降级失败" }, status: :unprocessable_entity
      end
    end

    # GET /api/admin/events/pending
    def pending_events
      events = ReadingEvent.includes(:leader)
                      .where(approval_status: :pending)
                      .order(created_at: :desc)

      render json: {
        events: events.map { |event|
          {
            id: event.id,
            title: event.title,
            book_name: event.book_name,
            leader: {
              id: event.leader.id,
              nickname: event.leader.nickname
            },
            created_at: event.created_at,
            enrollment_fee: event.enrollment_fee,
            max_participants: event.max_participants
          }
        },
        count: events.count
      }
    end

    # POST /api/admin/init_root
    def init_root_user
      # 这个接口用于系统初始化时创建root用户
      # 应该在系统部署后立即调用，然后禁用

      if User.exists?(role: :root)
        return render json: { error: "Root用户已存在" }, status: :unprocessable_entity
      end

      # 这里应该有更严格的验证，比如特定的token或者IP限制
      # 为了演示，这里简化处理
      root_info = params.require(:root).permit(:wx_openid, :nickname, :avatar_url)

      user = User.new(root_info)
      user.role = :root

      if user.save
        render json: {
          message: "Root用户创建成功",
          user: {
            id: user.id,
            nickname: user.nickname,
            role: user.role_display_name
          }
        }
      else
        render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def current_user_permissions
      [
        "approve_events",
        "view_admin_panel"
      ].select { |perm| current_user.has_permission?(perm.to_sym) }
    end

    def admin_available_actions
      actions = []
      actions << { action: "approve_events", description: "审批活动" } if current_user.can_approve_events?
      actions << { action: "manage_users", description: "管理用户" } if current_user.can_manage_users?
      actions << { action: "view_admin_panel", description: "查看管理面板" } if current_user.can_view_admin_panel?
      actions << { action: "manage_system", description: "管理系统" } if current_user.can_manage_system?
      actions
    end

    def user_permissions_for(user)
      permissions = []
      permissions << "approve_events" if user.can_approve_events?
      permissions << "manage_users" if user.can_manage_users?
      permissions << "view_admin_panel" if user.can_view_admin_panel?
      permissions << "manage_system" if user.can_manage_system?
      permissions
    end
  end
end
end