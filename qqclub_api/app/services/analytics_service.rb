# 分析服务
# 负责提供系统各方面的统计分析功能
class AnalyticsService
  class << self
    # 获取系统总览统计
    def system_overview
      {
        users: user_statistics,
        events: event_statistics,
        check_ins: check_in_statistics,
        flowers: flower_statistics,
        notifications: notification_statistics,
        engagement: engagement_statistics
      }
    end

    # 用户统计
    def user_statistics
      {
        total_users: User.count,
        active_users_7_days: active_users_count(7.days.ago),
        active_users_30_days: active_users_count(30.days.ago),
        new_users_today: User.where('created_at >= ?', Date.current).count,
        new_users_7_days: User.where('created_at >= ?', 7.days.ago).count,
        new_users_30_days: User.where('created_at >= ?', 30.days.ago).count,
        user_roles: User.group(:role).count
      }
    end

    # 活动统计
    def event_statistics
      {
        total_events: ReadingEvent.count,
        active_events: ReadingEvent.where(status: ['enrolling', 'in_progress']).count,
        completed_events: ReadingEvent.where(status: 'completed').count,
        draft_events: ReadingEvent.where(status: 'draft').count,
        events_7_days: ReadingEvent.where('created_at >= ?', 7.days.ago).count,
        events_30_days: ReadingEvent.where('created_at >= ?', 30.days.ago).count,
        approval_stats: {
          pending: ReadingEvent.where(approval_status: 'pending').count,
          approved: ReadingEvent.where(approval_status: 'approved').count,
          rejected: ReadingEvent.where(approval_status: 'rejected').count
        },
        activity_modes: ReadingEvent.group(:activity_mode).count
      }
    end

    # 打卡统计
    def check_in_statistics
      all_check_ins = CheckIn.all

      # 计算质量分布（使用计算属性）
      quality_scores = all_check_ins.map(&:quality_score).compact
      quality_distribution = quality_scores.group_by { |score| score / 10 * 10 }.transform_values(&:count)

      {
        total_check_ins: all_check_ins.count,
        check_ins_today: all_check_ins.where('created_at >= ?', Date.current).count,
        check_ins_7_days: all_check_ins.where('created_at >= ?', 7.days.ago).count,
        check_ins_30_days: all_check_ins.where('created_at >= ?', 30.days.ago).count,
        quality_distribution: quality_distribution,
        status_distribution: all_check_ins.group(:status).count,
        average_word_count: all_check_ins.average(:word_count)&.round(2) || 0,
        high_quality_rate: ((all_check_ins.select(&:high_quality?).count.to_f / all_check_ins.count * 100).round(2) rescue 0)
      }
    end

    # 小红花统计
    def flower_statistics
      {
        total_flowers: Flower.count,
        flowers_today: Flower.where('created_at >= ?', Date.current).count,
        flowers_7_days: Flower.where('created_at >= ?', 7.days.ago).count,
        flowers_30_days: Flower.where('created_at >= ?', 30.days.ago).count,
        unique_givers: Flower.distinct.count(:giver_id),
        unique_receivers: Flower.distinct.count(:recipient_id),
        flower_types: Flower.group(:flower_type).count,
        average_amount: Flower.average(:amount)&.round(2) || 0,
        comments_count: Flower.where.not(comment: [nil, '']).count
      }
    end

    # 通知统计
    def notification_statistics
      {
        total_notifications: Notification.count,
        notifications_today: Notification.where('created_at >= ?', Date.current).count,
        notifications_7_days: Notification.where('created_at >= ?', 7.days.ago).count,
        notifications_30_days: Notification.where('created_at >= ?', 30.days.ago).count,
        unread_notifications: Notification.where(read: false).count,
        read_rate: ((Notification.where(read: true).count.to_f / Notification.count * 100).round(2) rescue 0),
        notification_types: Notification.group(:notification_type).count
      }
    end

    # 参与度统计
    def engagement_statistics
      {
        average_event_participants: average_participants_per_event,
        average_check_ins_per_event: average_check_ins_per_event,
        average_flowers_per_event: average_flowers_per_event,
        user_retention_rate: user_retention_rate,
        daily_active_users: daily_active_users_data(7.days.ago),
        popular_event_types: most_popular_event_types
      }
    end

    # 用户详细统计
    def user_analytics(user, days = 30)
      start_date = days.days.ago

      {
        profile: user_profile_stats(user, start_date),
        participation: user_participation_stats(user, start_date),
        engagement: user_engagement_stats(user, start_date),
        achievements: user_achievement_stats(user, start_date)
      }
    end

    # 活动详细统计
    def event_analytics(event)
      {
        overview: event_overview_stats(event),
        participation: event_participation_stats(event),
        engagement: event_engagement_stats(event),
        timeline: event_timeline_stats(event),
        feedback: event_feedback_stats(event)
      }
    end

    # 趋势数据
    def trend_data(metric, period = :week, days = 30)
      start_date = days.days.ago
      data_points = generate_time_points(start_date, period)

      data_points.map do |date|
        value = case metric
        when :check_ins
          CheckIn.where(created_at: date..end_of_period(date, period)).count
        when :flowers
          Flower.where(created_at: date..end_of_period(date, period)).count
        when :users
          User.where(created_at: date..end_of_period(date, period)).count
        when :events
          ReadingEvent.where(created_at: date..end_of_period(date, period)).count
        when :notifications
          Notification.where(created_at: date..end_of_period(date, period)).count
        else
          0
        end

        {
          date: date.strftime('%Y-%m-%d'),
          value: value
        }
      end
    end

    # 排行榜数据
    def leaderboards(type = :flowers, limit = 10, period = :all_time)
      case type
      when :flowers
        flowers_leaderboard(limit, period)
      when :check_ins
        check_ins_leaderboard(limit, period)
      when :participation
        participation_leaderboard(limit, period)
      else
        []
      end
    end

    private

    # 活跃用户数量
    def active_users_count(since)
      User.joins(:check_ins)
          .where('check_ins.created_at >= ?', since)
          .distinct
          .count
    end

    # 每个活动的平均参与人数
    def average_participants_per_event
      return 0 if ReadingEvent.count == 0

      total_participants = ReadingEvent.joins(:event_enrollments)
                                     .where(event_enrollments: { status: 'enrolled' })
                                     .count
      (total_participants.to_f / ReadingEvent.count).round(2)
    end

    # 每个活动的平均打卡数
    def average_check_ins_per_event
      return 0 if ReadingEvent.count == 0

      total_check_ins = CheckIn.joins(reading_event: :event_enrollments)
                               .count
      (total_check_ins.to_f / ReadingEvent.count).round(2)
    end

    # 每个活动的平均小红花数
    def average_flowers_per_event
      return 0 if ReadingEvent.count == 0

      total_flowers = Flower.joins(check_in: { reading_event: :event_enrollments })
                           .count
      (total_flowers.to_f / ReadingEvent.count).round(2)
    end

    # 用户留存率
    def user_retention_rate
      new_users_30_days_ago = User.where('created_at BETWEEN ? AND ?', 60.days.ago, 30.days.ago)
      return 0 if new_users_30_days_ago.count == 0

      retained_users = new_users_30_days_ago.joins(:check_ins)
                                           .where('check_ins.created_at >= ?', 30.days.ago)
                                           .distinct
                                           .count

      (retained_users.to_f / new_users_30_days_ago.count * 100).round(2)
    end

    # 每日活跃用户数据
    def daily_active_users_data(since)
      (since.to_date..Date.current).map do |date|
        active_users = User.joins(:check_ins)
                          .where('check_ins.created_at >= ? AND check_ins.created_at < ?',
                                date.beginning_of_day, date.end_of_day)
                          .distinct
                          .count

        {
          date: date.strftime('%Y-%m-%d'),
          active_users: active_users
        }
      end
    end

    # 最受欢迎的活动类型
    def most_popular_event_types
      ReadingEvent.joins(:event_enrollments)
                  .group('reading_events.activity_mode')
                  .count('event_enrollments.id')
                  .sort_by { |_, count| -count }
                  .first(5)
                  .map { |mode, count| { activity_mode: mode, participants: count } }
    end

    # 用户档案统计
    def user_profile_stats(user, start_date)
      {
        user_id: user.id,
        nickname: user.nickname,
        member_since: user.created_at,
        last_active: last_activity_date(user),
        participation_score: calculate_participation_score(user, start_date),
        influence_score: calculate_influence_score(user, start_date)
      }
    end

    # 用户参与统计
    def user_participation_stats(user, start_date)
      enrollments = user.event_enrollments.where('created_at >= ?', start_date)

      {
        events_enrolled: enrollments.count,
        events_completed: enrollments.where(status: 'completed').count,
        completion_rate: calculate_completion_rate(enrollments),
        check_ins_total: user.check_ins.where('created_at >= ?', start_date).count,
        average_check_ins_per_event: calculate_avg_check_ins_per_event(enrollments)
      }
    end

    # 用户互动统计
    def user_engagement_stats(user, start_date)
      {
        flowers_given: user.given_flowers.where('created_at >= ?', start_date).count,
        flowers_received: user.received_flowers.where('created_at >= ?', start_date).count,
        comments_given: user.comments.where('created_at >= ?', start_date).count,
        notifications_sent: Notification.where(actor: user).where('created_at >= ?', start_date).count,
        interaction_score: calculate_interaction_score(user, start_date)
      }
    end

    # 用户成就统计
    def user_achievement_stats(user, start_date)
      {
        certificates_count: user.flower_certificates.where('created_at >= ?', start_date).count,
        top_three_finishes: user.flower_certificates.where(rank: [1, 2, 3]).count,
        high_quality_check_ins: user.check_ins.where('created_at >= ?', start_date).select(&:high_quality?).count,
        streak_days: calculate_current_streak(user),
        achievements: get_user_achievements(user, start_date)
      }
    end

    # 活动概览统计
    def event_overview_stats(event)
      {
        event_id: event.id,
        title: event.title,
        status: event.status,
        approval_status: event.approval_status,
        created_at: event.created_at,
        start_date: event.start_date,
        end_date: event.end_date,
        duration_days: event.days_count,
        activity_mode: event.activity_mode
      }
    end

    # 活动参与统计
    def event_participation_stats(event)
      enrollments = event.event_enrollments

      {
        total_enrollments: enrollments.count,
        active_enrollments: enrollments.where(status: 'enrolled').count,
        completed_enrollments: enrollments.where(status: 'completed').count,
        completion_rate: calculate_event_completion_rate(enrollments),
        average_completion_rate: enrollments.average(:completion_rate)&.round(2) || 0,
        participation_trend: participation_trend_data(event)
      }
    end

    # 活动互动统计
    def event_engagement_stats(event)
      {
        total_check_ins: event.check_ins.count,
        unique_participants_checking_in: event.check_ins.distinct.count(:user_id),
        average_check_ins_per_participant: calculate_avg_check_ins(event),
        total_flowers: event.flowers_count,
        flowers_per_check_in: calculate_flowers_per_check_in(event),
        engagement_score: calculate_event_engagement_score(event)
      }
    end

    # 活动时间线统计
    def event_timeline_stats(event)
      if event.status == 'completed'
        {
          total_duration: event.days_count,
          actual_start_date: event.reading_schedules.minimum(:date),
          actual_end_date: event.reading_schedules.maximum(:date),
          peak_activity_day: find_peak_activity_day(event),
          daily_participation: daily_participation_data(event)
        }
      else
        {
          planned_duration: event.days_count,
          progress_percentage: calculate_event_progress(event),
          current_day: calculate_current_event_day(event),
          daily_activity: daily_activity_data(event)
        }
      end
    end

    # 活动反馈统计
    def event_feedback_stats(event)
      {
        average_rating: calculate_average_rating(event),
        feedback_count: count_feedback_responses(event),
        satisfaction_rate: calculate_satisfaction_rate(event),
        common_themes: analyze_feedback_themes(event)
      }
    end

    # 生成时间点
    def generate_time_points(start_date, period)
      case period
      when :day
        (start_date.to_date..Date.current).to_a
      when :week
        weeks = []
        current = start_date.to_date.beginning_of_week
        while current <= Date.current
          weeks << current
          current += 1.week
        end
        weeks
      when :month
        months = []
        current = start_date.to_date.beginning_of_month
        while current <= Date.current
          months << current
          current += 1.month
        end
        months
      else
        [start_date.to_date]
      end
    end

    # 期间的结束时间
    def end_of_period(date, period)
      case period
      when :day
        date.end_of_day
      when :week
        date.end_of_week
      when :month
        date.end_of_month
      else
        date.end_of_day
      end
    end

    # 小红花排行榜
    def flowers_leaderboard(limit, period)
      flowers_query = Flower.all

      case period
      when :today
        flowers_query = flowers_query.where('created_at >= ?', Date.current)
      when :week
        flowers_query = flowers_query.where('created_at >= ?', 1.week.ago)
      when :month
        flowers_query = flowers_query.where('created_at >= ?', 1.month.ago)
      end

      # 简化实现：先查询小红花，然后按用户分组统计
      user_flower_stats = {}

      flowers_query.includes(:recipient).find_each do |flower|
        recipient_id = flower.recipient_id
        user_flower_stats[recipient_id] ||= {
          user: flower.recipient,
          total_flowers: 0,
          flowers_count: 0
        }

        user_flower_stats[recipient_id][:total_flowers] += flower.amount || 1
        user_flower_stats[recipient_id][:flowers_count] += 1
      end

      # 按总数排序并限制数量
      user_flower_stats.values
                         .sort_by { |stats| -stats[:total_flowers] }
                         .first(limit)
                         .map.with_index(1) do |stats, index|
                           {
                             user: stats[:user].as_json_for_api,
                             total_flowers: stats[:total_flowers],
                             flowers_count: stats[:flowers_count],
                             rank: index
                           }
                         end
    end

    # 打卡排行榜
    def check_ins_leaderboard(limit, period)
      check_ins_query = CheckIn.all

      case period
      when :today
        check_ins_query = check_ins_query.where('created_at >= ?', Date.current)
      when :week
        check_ins_query = check_ins_query.where('created_at >= ?', 1.week.ago)
      when :month
        check_ins_query = check_ins_query.where('created_at >= ?', 1.month.ago)
      end

      # 简化实现：先查询打卡，然后按用户分组统计
      user_check_in_stats = {}

      check_ins_query.includes(:user).find_each do |check_in|
        user_id = check_in.user_id
        user_check_in_stats[user_id] ||= {
          user: check_in.user,
          check_ins_count: 0,
          quality_scores: []
        }

        user_check_in_stats[user_id][:check_ins_count] += 1
        user_check_in_stats[user_id][:quality_scores] << check_in.quality_score if check_in.quality_score
      end

      # 计算平均质量分并排序
      user_check_in_stats.values
                           .map do |stats|
                             avg_quality = if stats[:quality_scores].any?
                                           stats[:quality_scores].sum.to_f / stats[:quality_scores].count
                                         else
                                           0
                                         end

                             {
                               user: stats[:user].as_json_for_api,
                               check_ins_count: stats[:check_ins_count],
                               average_quality: avg_quality.round(2),
                               rank: 0
                             }
                           end
                           .sort_by { |stats| [-stats[:check_ins_count], -stats[:average_quality]] }
                           .first(limit)
                           .map.with_index(1) { |stats, index| stats.merge(rank: index) }
    end

    # 参与度排行榜
    def participation_leaderboard(limit, period)
      enrollments_query = EventEnrollment.all

      case period
      when :today
        enrollments_query = enrollments_query.where('created_at >= ?', Date.current)
      when :week
        enrollments_query = enrollments_query.where('created_at >= ?', 1.week.ago)
      when :month
        enrollments_query = enrollments_query.where('created_at >= ?', 1.month.ago)
      end

      # 简化实现：先查询报名，然后按用户分组统计
      user_enrollment_stats = {}

      enrollments_query.includes(:user).find_each do |enrollment|
        user_id = enrollment.user_id
        event_id = enrollment.reading_event_id
        completion_rate = enrollment.completion_rate || 0

        user_enrollment_stats[user_id] ||= {
          user: enrollment.user,
          events_count: 0,
          event_ids: Set.new,
          completion_rates: []
        }

        user_enrollment_stats[user_id][:events_count] += 1
        user_enrollment_stats[user_id][:event_ids] << event_id
        user_enrollment_stats[user_id][:completion_rates] << completion_rate
      end

      # 计算统计数据并排序
      user_enrollment_stats.values
                            .map do |stats|
                              unique_events = stats[:event_ids].size
                              avg_completion = if stats[:completion_rates].any?
                                                stats[:completion_rates].sum.to_f / stats[:completion_rates].count
                                              else
                                                0
                                              end

                              {
                                user: stats[:user].as_json_for_api,
                                events_count: unique_events,
                                average_completion: avg_completion.round(2),
                                rank: 0
                              }
                            end
                            .sort_by { |stats| [-stats[:events_count], -stats[:average_completion]] }
                            .first(limit)
                            .map.with_index(1) { |stats, index| stats.merge(rank: index) }
    end

    # 辅助方法（计算各种指标）
    def last_activity_date(user)
      user.check_ins.maximum(:created_at) ||
      user.flowers.maximum(:created_at) ||
      user.comments.maximum(:created_at) ||
      user.created_at
    end

    def calculate_participation_score(user, start_date)
      # 基于活动参与、打卡次数、完成率等计算
      enrollments = user.event_enrollments.where('created_at >= ?', start_date)
      check_ins = user.check_ins.where('created_at >= ?', start_date)

      base_score = enrollments.count * 10
      check_in_score = check_ins.count * 5
      completion_bonus = enrollments.where(status: 'completed').count * 20

      base_score + check_in_score + completion_bonus
    end

    def calculate_influence_score(user, start_date)
      # 基于小红花、评论、通知等计算影响力
      flowers_given = user.given_flowers.where('created_at >= ?', start_date).count
      comments = user.comments.where('created_at >= ?', start_date).count

      flowers_given * 15 + comments * 10
    end

    def calculate_completion_rate(enrollments)
      return 0 if enrollments.empty?
      completed = enrollments.where(status: 'completed').count
      (completed.to_f / enrollments.count * 100).round(2)
    end

    def calculate_avg_check_ins_per_event(enrollments)
      return 0 if enrollments.empty?
      # 避免JOIN查询中的列名冲突，改用子查询
      check_in_ids = CheckIn.where(enrollment_id: enrollments.pluck(:id)).pluck(:id)
      total_check_ins = check_in_ids.count
      (total_check_ins.to_f / enrollments.count).round(2)
    end

    def calculate_interaction_score(user, start_date)
      flowers_received = user.received_flowers.where('created_at >= ?', start_date).count
      # 这里简化处理，因为 Comment 可能不直接与 User 关联
      comments_received = 0 # Comment.where(commentable: user).where('created_at >= ?', start_date).count

      flowers_received * 10 + comments_received * 5
    end

    def calculate_current_streak(user)
      # 计算用户当前的打卡连续天数
      # 这里简化实现，实际可以更复杂
      recent_check_ins = user.check_ins.where('created_at >= ?', 30.days.ago)
                                  .order(created_at: :desc)

      return 0 if recent_check_ins.empty?

      streak = 0
      current_date = Date.current

      recent_check_ins.each do |check_in|
        if check_in.created_at.to_date == current_date
          streak += 1
          current_date -= 1.day
        else
          break
        end
      end

      streak
    end

    def get_user_achievements(user, start_date)
      # 获取用户成就徽章等
      achievements = []

      # 基于各种条件授予成就
      if user.check_ins.where('created_at >= ?', start_date).count >= 30
        achievements << { name: '勤奋打卡', description: '30天内打卡超过30次' }
      end

      if user.received_flowers.where('created_at >= ?', start_date).count >= 10
        achievements << { name: '人气之星', description: '30天内收到超过10朵小红花' }
      end

      achievements
    end

    def calculate_event_completion_rate(enrollments)
      return 0 if enrollments.empty?
      completed = enrollments.where(status: 'completed').count
      (completed.to_f / enrollments.count * 100).round(2)
    end

    def calculate_avg_check_ins(event)
      return 0 if event.event_enrollments.empty?
      total_check_ins = event.check_ins.count
      (total_check_ins.to_f / event.event_enrollments.count).round(2)
    end

    def calculate_flowers_per_check_in(event)
      check_ins_count = event.check_ins.count
      flowers_count = event.flowers_count

      return 0 if check_ins_count == 0
      (flowers_count.to_f / check_ins_count).round(2)
    end

    def calculate_event_engagement_score(event)
      # 综合评分：打卡率 + 小红花率 + 完成率
      check_in_rate = [calculate_avg_check_ins(event) * 10, 100].min
      flower_rate = [calculate_flowers_per_check_in(event) * 20, 100].min
      completion_rate = calculate_event_completion_rate(event.event_enrollments)

      (check_in_rate * 0.4 + flower_rate * 0.3 + completion_rate * 0.3).round(2)
    end

    def calculate_event_progress(event)
      return 100 if event.status == 'completed'
      return 0 if event.status == 'draft'

      total_days = event.days_count
      return 0 if total_days == 0

      elapsed_days = [(Date.current - event.start_date).to_i, 0].max
      [elapsed_days.to_f / total_days * 100, 100].min.round(2)
    end

    def calculate_current_event_day(event)
      return 0 if event.start_date.nil?

      elapsed = [(Date.current - event.start_date).to_i + 1, 1].max
      [elapsed, event.days_count].min
    end

    # 更多辅助方法可以根据需要继续添加...
  end
end