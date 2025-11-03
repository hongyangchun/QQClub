# 小红花统计服务
# 提供小红花统计、排行榜、数据分析功能
class FlowerStatisticsService
  class << self
    # 获取用户小红花统计
    def get_user_flower_stats(user, days = 30)
      start_date = days.days.ago.to_date

      received = Flower.joins(:check_in)
                     .where(recipient: user)
                     .where('flowers.created_at >= ?', start_date)
                     .group(:flower_type)
                     .sum(:amount)

      given = Flower.where(giver: user)
                   .where('flowers.created_at >= ?', start_date)
                   .group(:flower_type)
                   .sum(:amount)

      # 按天统计
      daily_received = Flower.joins(:check_in)
                         .where(recipient: user)
                         .where('flowers.created_at >= ?', start_date)
                         .group('DATE(flowers.created_at)')
                         .sum(:amount)

      daily_given = Flower.where(giver: user)
                       .where('flowers.created_at >= ?', start_date)
                       .group('DATE(flowers.created_at)')
                       .sum(:amount)

      {
        period: "#{days}天",
        total_received: received.values.sum,
        total_given: given.values.sum,
        received_by_type: received,
        given_by_type: given,
        daily_received: daily_received,
        daily_given: daily_given,
        net_balance: received.values.sum - given.values.sum
      }
    end

    # 获取活动小红花统计
    def get_event_flower_stats(event, days = 30)
      start_date = days.days.ago.to_date

      flowers = Flower.joins(:check_in)
                     .joins(:reading_schedule)
                     .where(reading_schedules: { reading_event_id: event.id })
                     .where('flowers.created_at >= ?', start_date)

      # 按天统计
      daily_stats = flowers.group('DATE(flowers.created_at)').count

      # 按类型统计
      type_stats = flowers.group(:flower_type).count

      # 参与度统计
      participant_stats = flowers.group(:recipient_id).count

      # 发放者统计
      giver_stats = flowers.group(:giver_id).count

      {
        period: "#{days}天",
        total_flowers: flowers.count,
        daily_stats: daily_stats,
        type_stats: type_stats,
        participant_count: participant_stats.keys.count,
        giver_count: giver_stats.keys.count,
        avg_flowers_per_participant: participant_stats.values.empty? ? 0 : (participant_stats.values.sum.to_f / participant_stats.count).round(2)
      }
    end

    # 获取小红花排行榜
    def get_flower_leaderboard(type = 'received', period = 30, limit = 20)
      start_date = period.days.ago.to_date

      case type.to_sym
      when :received
        get_received_leaderboard(start_date, limit)
      when :given
        get_given_leaderboard(start_date, limit)
      when :popular_check_ins
        get_popular_check_ins_leaderboard(start_date, limit)
      when :generous_givers
        get_generous_givers_leaderboard(start_date, limit)
      else
        get_received_leaderboard(start_date, limit)
      end
    end

    # 获取小红花趋势数据
    def get_flower_trends(days = 30)
      start_date = days.days.ago.to_date
      end_date = Date.current

      trends = {}
      (start_date..end_date).each do |date|
        flowers = Flower.where('DATE(flowers.created_at) = ?', date)
        trends[date.to_s] = {
          total: flowers.count,
          received: flowers.where.not(giver_id: nil).count,
          given: flowers.where.not(recipient_id: nil).count
        }
      end

      trends
    end

    # 获取小红花激励统计
    def get_incentive_statistics(days = 30)
      start_date = days.days.ago.to_date
      end_date = Date.current

      # 小红花发放活动参与度
      active_events = ReadingEvent.joins(check_ins: :flowers)
                         .where('reading_events.start_date <= ? AND reading_events.end_date >= ?', end_date, start_date)
                         .where('flowers.created_at >= ?', start_date)
                         .distinct
                         .count

      # 活跃用户（发送或接收小红花）
      active_users = Flower.where('flowers.created_at >= ?', start_date)
                       .select('DISTINCT giver_id, recipient_id')
                       .flat_map { |r| [r.giver_id, r.recipient_id] }
                       .uniq
                       .count

      # 小红花流转情况
      total_flowers = Flower.where('flowers.created_at >= ?', start_date).count
      avg_flowers_per_day = total_flowers.to_f / days

      {
        period: "#{days}天",
        active_events: active_events,
        active_users: active_users,
        total_flowers: total_flowers,
        avg_flowers_per_day: avg_flowers_per_day.round(2),
        flower_velocity: calculate_flower_velocity(start_date, days)
      }
    end

    # 获取小红花发放建议
    def get_flower_suggestions(user, limit = 5)
      # 建议给哪些打卡送小红花
      suggestions = []

      # 1. 最近的高质量打卡但小红花较少的内容
      recent_check_ins = CheckIn.joins(:flowers)
                             .where.not(check_ins: { user_id: user.id })
                             .where('check_ins.created_at >= ?', 7.days.ago)
                             .where('check_ins.word_count >= 100')
                             .group('check_ins.id')
                             .having('COUNT(flowers.id) < 3')
                             .order('check_ins.created_at DESC')
                             .limit(limit)

      recent_check_ins.each do |check_in|
        suggestions << {
          type: 'check_in',
          check_in: check_in,
          reason: '高质量内容但小红花较少',
          priority: 1
        }
      end

      # 2. 活跃的参与者 - 简化版本，只考虑最近打卡的用户
      active_participants = User.joins(:check_ins)
                                   .where('check_ins.created_at >= ?', 7.days.ago)
                                   .where.not(users: { id: user.id })
                                   .group('users.id')
                                   .having('COUNT(check_ins.id) >= 3')
                                   .select('users.*')
                                   .order('COUNT(check_ins.id) DESC')
                                   .limit(limit)

      active_participants.each do |participant|
        suggestions << {
          type: 'user',
          user: participant,
          reason: '活跃参与者',
          priority: 2
        }
      end

      suggestions.sort_by { |s| s[:priority] }.first(limit)
    end

    # 计算小红花流速
    def calculate_flower_velocity(start_date, days)
      flowers = Flower.where('flowers.created_at >= ?', start_date)
                   .order(:created_at)

      return 0.0 if flowers.count < 2

      first_flower = flowers.first
      last_flower = flowers.last

      time_span = (last_flower.created_at - first_flower.created_at) / 1.hour
      return 0.0 if time_span < 1

      (flowers.count - 1).to_f / time_span.round(2)
    end

    private

    # 获取接收排行榜
    def get_received_leaderboard(start_date, limit)
      flower_sums = Flower.where('flowers.created_at >= ?', start_date)
                           .joins(:recipient)
                           .group(:recipient_id)
                           .sum(:amount)

      user_ids = flower_sums.keys.sort_by { |user_id| -flower_sums[user_id] }.first(limit)
      users = User.where(id: user_ids).index_by(&:id)

      user_ids.map do |user_id|
        user = users[user_id]
        next unless user

        # 添加total_flowers属性
        user.define_singleton_method(:total_flowers) { flower_sums[user_id] }
        user
      end.compact
    end

    # 获取赠送排行榜
    def get_given_leaderboard(start_date, limit)
      flower_sums = Flower.where('flowers.created_at >= ?', start_date)
                           .joins(:giver)
                           .group(:giver_id)
                           .sum(:amount)

      user_ids = flower_sums.keys.sort_by { |user_id| -flower_sums[user_id] }.first(limit)
      users = User.where(id: user_ids).index_by(&:id)

      user_ids.map do |user_id|
        user = users[user_id]
        next unless user

        # 添加total_flowers属性
        user.define_singleton_method(:total_flowers) { flower_sums[user_id] }
        user
      end.compact
    end

    # 获取热门打卡排行榜
    def get_popular_check_ins_leaderboard(start_date, limit)
      flower_counts = Flower.where('flowers.created_at >= ?', start_date)
                             .group(:check_in_id)
                             .count

      check_in_ids = flower_counts.keys.sort_by { |check_in_id| -flower_counts[check_in_id] }.first(limit)
      check_ins = CheckIn.where(id: check_in_ids).includes(:user).index_by(&:id)

      check_in_ids.map do |check_in_id|
        check_in = check_ins[check_in_id]
        next unless check_in

        # 添加flower_count属性
        check_in.define_singleton_method(:flower_count) { flower_counts[check_in_id] }
        check_in
      end.compact
    end

    # 获取慷慨赠送者排行榜
    def get_generous_givers_leaderboard(start_date, limit)
      flower_counts = Flower.where('flowers.created_at >= ?', start_date)
                             .where.not(is_anonymous: true)
                             .group(:giver_id)
                             .count

      user_ids = flower_counts.keys.sort_by { |user_id| -flower_counts[user_id] }.first(limit)
      users = User.where(id: user_ids).index_by(&:id)

      user_ids.map do |user_id|
        user = users[user_id]
        next unless user

        # 添加giving_count属性
        user.define_singleton_method(:giving_count) { flower_counts[user_id] }
        user
      end.compact
    end
  end
end