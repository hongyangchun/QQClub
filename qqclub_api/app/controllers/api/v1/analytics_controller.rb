# frozen_string_literal: true

class Api::V1::AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin_for_system_analytics

  # GET /api/v1/analytics/overview
  # 获取系统总览统计（管理员）
  def overview
    render json: {
      success: true,
      data: AnalyticsService.system_overview,
      generated_at: Time.current
    }
  end

  # GET /api/v1/analytics/dashboard
  # 获取用户仪表板数据
  def dashboard
    days = params[:days]&.to_i || 30
    user_analytics = AnalyticsService.user_analytics(current_user, days)

    render json: {
      success: true,
      data: user_analytics,
      period: "#{days} 天",
      generated_at: Time.current
    }
  end

  # GET /api/v1/analytics/events/:id
  # 获取活动详细统计
  def event_stats
    event = ReadingEvent.find(params[:id])

    # 检查权限：活动创建者、管理员或参与者可以查看统计
    unless can_view_event_analytics?(event)
      return render json: {
        success: false,
        error: '无权限查看此活动统计'
      }, status: :forbidden
    end

    analytics = AnalyticsService.event_analytics(event)

    render json: {
      success: true,
      data: analytics,
      generated_at: Time.current
    }
  end

  # GET /api/v1/analytics/trends
  # 获取趋势数据
  def trends
    metric = params[:metric]&.to_sym
    period = params[:period]&.to_sym || :week
    days = params[:days]&.to_i || 30

    unless [:check_ins, :flowers, :users, :events, :notifications].include?(metric)
      return render json: {
        success: false,
        error: '无效的指标类型。支持的类型: check_ins, flowers, users, events, notifications'
      }, status: :bad_request
    end

    unless [:day, :week, :month].include?(period)
      return render json: {
        success: false,
        error: '无效的时间周期。支持的周期: day, week, month'
      }, status: :bad_request
    end

    trend_data = AnalyticsService.trend_data(metric, period, days)

    render json: {
      success: true,
      metric: metric,
      period: period,
      days: days,
      data: trend_data,
      generated_at: Time.current
    }
  end

  # GET /api/v1/analytics/leaderboards
  # 获取排行榜数据
  def leaderboards
    type = params[:type]&.to_sym || :flowers
    limit = params[:limit]&.to_i || 10
    period = params[:period]&.to_sym || :all_time

    unless [:flowers, :check_ins, :participation].include?(type)
      return render json: {
        success: false,
        error: '无效的排行榜类型。支持的类型: flowers, check_ins, participation'
      }, status: :bad_request
    end

    unless [:today, :week, :month, :all_time].include?(period)
      return render json: {
        success: false,
        error: '无效的时间周期。支持的周期: today, week, month, all_time'
      }, status: :bad_request
    end

    leaderboard_data = AnalyticsService.leaderboards(type, limit, period)

    render json: {
      success: true,
      type: type,
      period: period,
      limit: limit,
      data: leaderboard_data,
      generated_at: Time.current
    }
  end

  # GET /api/v1/analytics/users/:id
  # 获取用户详细统计（管理员功能）
  def user_stats
    user = User.find(params[:id])
    days = params[:days]&.to_i || 30

    unless current_user.any_admin? || current_user.id == user.id
      return render json: {
        success: false,
        error: '无权限查看此用户统计'
      }, status: :forbidden
    end

    analytics = AnalyticsService.user_analytics(user, days)

    render json: {
      success: true,
      data: analytics,
      period: "#{days} 天",
      generated_at: Time.current
    }
  end

  # GET /api/v1/analytics/summary
  # 获取简化的统计数据摘要
  def summary
    summary_data = {
      system: {
        total_users: User.count,
        active_events: ReadingEvent.where(status: ['enrolling', 'in_progress']).count,
        today_check_ins: CheckIn.where('created_at >= ?', Date.current).count,
        today_flowers: Flower.where('created_at >= ?', Date.current).count
      },
      user: {
        enrolled_events: current_user.event_enrollments.where(status: 'enrolled').count,
        my_check_ins: current_user.check_ins.where('created_at >= ?', 7.days.ago).count,
        flowers_received: current_user.received_flowers.where('created_at >= ?', 7.days.ago).count,
        notifications_unread: current_user.received_notifications.unread.count
      }
    }

    render json: {
      success: true,
      data: summary_data,
      generated_at: Time.current
    }
  end

  # GET /api/v1/analytics/reports
  # 生成报告（管理员功能）
  def reports
    report_type = params[:type]&.to_sym
    format = params[:format]&.to_sym || :json

    unless current_user.any_admin?
      return render json: {
        success: false,
        error: '需要管理员权限'
      }, status: :forbidden
    end

    case report_type
    when :monthly
      report = generate_monthly_report
    when :activity
      report = generate_activity_report
    when :engagement
      report = generate_engagement_report
    else
      return render json: {
        success: false,
        error: '无效的报告类型。支持的类型: monthly, activity, engagement'
      }, status: :bad_request
    end

    render json: {
      success: true,
      report_type: report_type,
      data: report,
      generated_at: Time.current
    }
  end

  # GET /api/v1/analytics/export
  # 导出数据（管理员功能）
  def export
    export_type = params[:type]&.to_sym

    unless current_user.any_admin?
      return render json: {
        success: false,
        error: '需要管理员权限'
      }, status: :forbidden
    end

    case export_type
    when :users
      data = export_users_data
    when :events
      data = export_events_data
    when :flowers
      data = export_flowers_data
    else
      return render json: {
        success: false,
        error: '无效的导出类型。支持的类型: users, events, flowers'
      }, status: :bad_request
    end

    render json: {
      success: true,
      export_type: export_type,
      data: data,
      record_count: data.count,
      generated_at: Time.current
    }
  end

  private

  # 检查是否为系统分析需要管理员权限
  def require_admin_for_system_analytics
    return unless [:overview, :reports, :export].include?(action_name.to_sym)

    unless current_user.any_admin?
      render json: {
        success: false,
        error: '需要管理员权限'
      }, status: :forbidden
    end
  end

  # 检查是否可以查看活动分析
  def can_view_event_analytics?(event)
    return true if current_user.any_admin?
    return true if event.leader_id == current_user.id
    return true if event.participants.include?(current_user)
    false
  end

  # 生成月度报告
  def generate_monthly_report
    current_month = Date.current.beginning_of_month
    last_month = current_month - 1.month

    {
      current_month: {
        period: current_month.strftime('%Y年%m月'),
        users: {
          new: User.where(created_at: current_month..(current_month + 1.month)).count,
          active: active_users_in_period(current_month, (current_month + 1.month))
        },
        events: {
          created: ReadingEvent.where(created_at: current_month..(current_month + 1.month)).count,
          completed: ReadingEvent.where(status: 'completed', updated_at: current_month..(current_month + 1.month)).count
        },
        engagement: {
          check_ins: CheckIn.where(created_at: current_month..(current_month + 1.month)).count,
          flowers: Flower.where(created_at: current_month..(current_month + 1.month)).count
        }
      },
      comparison: {
        period: last_month.strftime('%Y年%m月'),
        user_growth: calculate_growth_rate(
          User.where(created_at: last_month..current_month).count,
          User.where(created_at: (last_month - 1.month)..last_month).count
        ),
        engagement_growth: calculate_growth_rate(
          CheckIn.where(created_at: current_month..(current_month + 1.month)).count,
          CheckIn.where(created_at: last_month..current_month).count
        )
      }
    }
  end

  # 生成活动报告
  def generate_activity_report
    status = params[:status] || 'all'

    events = ReadingEvent.all
    events = events.where(status: status) if status != 'all'

    events.map do |event|
      {
        id: event.id,
        title: event.title,
        status: event.status,
        participants_count: event.event_enrollments.where(status: 'enrolled').count,
        check_ins_count: event.check_ins.count,
        flowers_count: event.flowers_count,
        completion_rate: AnalyticsService.send(:calculate_event_completion_rate, event.event_enrollments),
        engagement_score: AnalyticsService.send(:calculate_event_engagement_score, event)
      }
    end
  end

  # 生成参与度报告
  def generate_engagement_report
    {
      user_engagement: user_engagement_metrics,
      event_engagement: event_engagement_metrics,
      daily_activity: daily_activity_metrics,
      trends: engagement_trends
    }
  end

  # 导出用户数据
  def export_users_data
    User.all.map do |user|
      {
        id: user.id,
        nickname: user.nickname,
        wx_openid: user.wx_openid,
        role: user.role_as_string,
        created_at: user.created_at,
        last_activity: user.check_ins.maximum(:created_at) || user.created_at,
        events_count: user.event_enrollments.count,
        check_ins_count: user.check_ins.count,
        flowers_given: user.given_flowers.count,
        flowers_received: user.received_flowers.count
      }
    end
  end

  # 导出活动数据
  def export_events_data
    ReadingEvent.all.map do |event|
      {
        id: event.id,
        title: event.title,
        book_name: event.book_name,
        leader: event.leader&.nickname,
        status: event.status,
        approval_status: event.approval_status,
        start_date: event.start_date,
        end_date: event.end_date,
        max_participants: event.max_participants,
        enrolled_count: event.event_enrollments.where(status: 'enrolled').count,
        check_ins_count: event.check_ins.count,
        flowers_count: event.flowers_count,
        created_at: event.created_at
      }
    end
  end

  # 导出小红花数据
  def export_flowers_data
    Flower.includes(:giver, :recipient, :check_in).all.map do |flower|
      {
        id: flower.id,
        giver: flower.giver&.nickname,
        recipient: flower.recipient&.nickname,
        check_in_content: flower.check_in&.content&.truncate(50),
        amount: flower.amount,
        flower_type: flower.flower_type,
        comment: flower.comment,
        created_at: flower.created_at
      }
    end
  end

  # 辅助方法
  def active_users_in_period(start_time, end_time)
    User.joins(:check_ins)
        .where('check_ins.created_at >= ? AND check_ins.created_at < ?', start_time, end_time)
        .distinct
        .count
  end

  def calculate_growth_rate(current, previous)
    return 0 if previous == 0
    ((current - previous).to_f / previous * 100).round(2)
  end

  def user_engagement_metrics
    {
      average_check_ins_per_user: CheckIn.count.to_f / [User.count, 1].max,
      average_flowers_per_user: Flower.count.to_f / [User.count, 1].max,
      user_retention_rate: AnalyticsService.send(:user_retention_rate)
    }
  end

  def event_engagement_metrics
    {
      average_participation_rate: calculate_average_participation_rate,
      average_completion_rate: calculate_average_completion_rate,
      most_active_events: most_active_events(5)
    }
  end

  def daily_activity_metrics
    (7.days.ago.to_date..Date.current).map do |date|
      {
        date: date.strftime('%Y-%m-%d'),
        check_ins: CheckIn.where(created_at: date.beginning_of_day..date.end_of_day).count,
        flowers: Flower.where(created_at: date.beginning_of_day..date.end_of_day).count,
        active_users: active_users_in_period(date.beginning_of_day, date.end_of_day)
      }
    end
  end

  def engagement_trends
    {
      check_ins_trend: AnalyticsService.trend_data(:check_ins, :week, 30),
      flowers_trend: AnalyticsService.trend_data(:flowers, :week, 30),
      users_trend: AnalyticsService.trend_data(:users, :week, 30)
    }
  end

  def calculate_average_participation_rate
    total_events = ReadingEvent.where(status: ['enrolling', 'in_progress', 'completed']).count
    return 0 if total_events == 0

    total_capacity = ReadingEvent.where(status: ['enrolling', 'in_progress', 'completed'])
                             .sum(:max_participants)
    total_enrolled = ReadingEvent.joins(:event_enrollments)
                                 .where(event_enrollments: { status: 'enrolled' })
                                 .count

    (total_enrolled.to_f / total_capacity * 100).round(2)
  end

  def calculate_average_completion_rate
    completed_enrollments = EventEnrollment.where(status: 'completed').count
    total_enrollments = EventEnrollment.where.not(status: 'cancelled').count
    return 0 if total_enrollments == 0

    (completed_enrollments.to_f / total_enrollments * 100).round(2)
  end

  def most_active_events(limit = 5)
    ReadingEvent.joins(:check_ins)
                .group('reading_events.id')
                .select('reading_events.*, COUNT(check_ins.id) as check_ins_count')
                .order('check_ins_count DESC')
                .limit(limit)
                .map do |event|
                  {
                    id: event.id,
                    title: event.title,
                    check_ins_count: event.check_ins_count,
                    flowers_count: event.flowers_count
                  }
                end
  end
end