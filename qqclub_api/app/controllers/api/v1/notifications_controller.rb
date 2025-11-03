# frozen_string_literal: true

class Api::V1::NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:show, :update, :destroy]

  # GET /api/v1/notifications
  # 获取用户的通知列表
  def index
    page = params[:page] || 1
    limit = params[:limit] || 20
    notification_type = params[:type]
    read_status = params[:read_status] # 'read', 'unread', or nil for all

    notifications = current_user.received_notifications.includes(:actor, :notifiable)

    # 按类型过滤
    notifications = notifications.by_type(notification_type) if notification_type.present?

    # 按读取状态过滤
    case read_status
    when 'read'
      notifications = notifications.read
    when 'unread'
      notifications = notifications.unread
    end

    # 分页
    total_count = notifications.count
    notifications = notifications.offset((page - 1) * limit).limit(limit)

    render json: {
      success: true,
      notifications: notifications.map { |n| n.as_json_for_api(include_actor: true, include_notifiable: true) },
      pagination: {
        current_page: page.to_i,
        total_count: total_count,
        total_pages: (total_count.to_f / limit).ceil,
        has_next: (page.to_i * limit) < total_count,
        has_prev: page.to_i > 1
      },
      stats: {
        unread_count: current_user.received_notifications.unread.count,
        total_count: total_count
      }
    }
  end

  # GET /api/v1/notifications/:id
  # 获取单个通知详情
  def show
    render json: {
      success: true,
      notification: @notification.as_json_for_api(include_actor: true, include_notifiable: true)
    }
  end

  # PATCH /api/v1/notifications/:id
  # 标记通知为已读
  def update
    if @notification.mark_as_read!
      render json: {
        success: true,
        message: '通知已标记为已读',
        notification: @notification.as_json_for_api
      }
    else
      render json: {
        success: false,
        error: '标记通知失败'
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/notifications/:id
  # 删除通知
  def destroy
    if @notification.destroy
      render json: {
        success: true,
        message: '通知已删除'
      }
    else
      render json: {
        success: false,
        error: '删除通知失败'
      }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/notifications/mark_all_read
  # 批量标记所有通知为已读
  def mark_all_read
    count = NotificationService.mark_all_as_read_for(current_user)

    render json: {
      success: true,
      message: "已标记 #{count} 条通知为已读",
      marked_count: count
    }
  end

  # DELETE /api/v1/notifications/batch
  # 批量删除通知
  def batch_destroy
    notification_ids = params[:notification_ids] || []

    if notification_ids.blank?
      return render json: {
        success: false,
        error: '请选择要删除的通知'
      }, status: :bad_request
    end

    deleted_count = NotificationService.delete_notifications(notification_ids, current_user)

    render json: {
      success: true,
      message: "已删除 #{deleted_count} 条通知",
      deleted_count: deleted_count
    }
  end

  # GET /api/v1/notifications/unread_count
  # 获取未读通知数量
  def unread_count
    count = NotificationService.unread_count_for(current_user)

    render json: {
      success: true,
      unread_count: count
    }
  end

  # GET /api/v1/notifications/stats
  # 获取通知统计信息
  def stats
    days = params[:days]&.to_i || 7
    stats = NotificationService.notification_stats_for(current_user, days)

    render json: {
      success: true,
      stats: stats,
      period: "#{days} 天"
    }
  end

  # GET /api/v1/notifications/recent
  # 获取最近的通知
  def recent
    limit = params[:limit]&.to_i || 5
    include_read = params[:include_read] == 'true'

    notifications = NotificationService.recent_notifications_for(current_user, limit, include_read)

    render json: {
      success: true,
      notifications: notifications.map { |n| n.as_json_for_api(include_actor: true) }
    }
  end

  # GET /api/v1/notifications/check_new
  # 检查是否有新通知
  def check_new
    since = params[:since]&.to_time
    has_new = NotificationService.has_new_notifications?(current_user, since: since)

    render json: {
      success: true,
      has_new: has_new,
      unread_count: NotificationService.unread_count_for(current_user)
    }
  end

  # POST /api/v1/notifications/test
  # 测试通知（仅开发环境）
  def test
    return render json: { error: '此功能仅在开发环境中可用' }, status: :forbidden unless Rails.env.development?

    # 创建测试通知
    test_notification = NotificationService.send_system_notification(
      current_user,
      '测试通知',
      '这是一个测试通知，用于验证通知系统功能。',
      actor: current_user
    )

    render json: {
      success: true,
      message: '测试通知已创建',
      notification: test_notification.first&.as_json_for_api
    }
  end

  private

  # 设置通知
  def set_notification
    @notification = current_user.received_notifications.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: '通知不存在' }, status: :not_found
  end
end