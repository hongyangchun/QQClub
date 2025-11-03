# 每日小红花统计服务
# 自动统计前一天的小红花数据，生成排行榜，支持分享功能
class DailyFlowerStatsService
  class << self
    # 生成指定日期的统计数据（默认为昨天）
    def generate_daily_stats(event, date = Date.yesterday, force: false)
      return { success: false, error: '活动不存在' } unless event
      return { success: false, error: '指定日期不是活动日' } unless event_reading_day?(event, date)

      # 检查是否已存在统计数据
      if DailyFlowerStat.exists_for_date?(event, date) && !force
        return { success: false, error: '该日期统计数据已存在' }
      end

      # 获取前一天的小红花数据
      flowers = get_flowers_for_date(event, date)
      return { success: false, error: '该日期无小红花数据' } if flowers.empty?

      # 生成排行榜
      leaderboard = generate_leaderboard(flowers)

      # 计算统计数据
      stats_data = calculate_statistics(flowers, event, date)

      # 创建或更新统计记录
      stat = DailyFlowerStat.find_or_initialize_by(reading_event: event, stats_date: date)
      stat.update!(
        leaderboard_data: {
          rankings: leaderboard,
          generated_at: Time.current,
          date: date,
          flower_count: flowers.count
        },
        total_flowers_given: stats_data[:total_flowers_given],
        total_participants: stats_data[:total_participants],
        total_givers: stats_data[:total_givers],
        generated_at: Time.current,
        generated_by: 'system_auto',
        share_text: generate_share_text(event, date, leaderboard),
        share_image_url: generate_share_image_url(event, date)
      )

      {
        success: true,
        message: '每日统计生成成功',
        stat: stat.as_json_for_api,
        summary: {
          date: date,
          event: event.title,
          total_flowers: stats_data[:total_flowers_given],
          total_participants: stats_data[:total_participants],
          top_three: leaderboard.first(3).map do |entry|
            user = User.find_by(id: entry[:user_id])
            {
              rank: entry[:rank],
              user: user&.as_json_for_api,
              total_flowers: entry[:total_flowers]
            }
          end
        }
      }
    rescue => e
      Rails.logger.error "每日统计生成失败: #{e.message}"
      {
        success: false,
        error: '统计生成失败',
        details: e.message
      }
    end

    # 批量生成多日统计（用于历史数据补全）
    def generate_batch_stats(event, start_date, end_date = nil)
      return { success: false, error: '活动不存在' } unless event

      end_date ||= event.end_date
      start_date = [start_date, event.start_date].max

      results = []
      failed_dates = []

      (start_date..end_date).each do |date|
        next unless event_reading_day?(event, date)
        next if date >= Date.current # 不处理今天和未来的日期

        result = generate_daily_stats(event, date, force: false)
        if result[:success]
          results << { date: date, success: true }
        else
          failed_dates << { date: date, error: result[:error] }
        end
      end

      {
        success: failed_dates.empty?,
        message: "批量统计完成",
        results: {
          processed: results.count,
          successful: results.count,
          failed: failed_dates.count,
          successful_dates: results,
          failed_dates: failed_dates
        }
      }
    end

    # 自动生成昨天的统计数据（定时任务调用）
    def auto_generate_yesterday_stats
      events = ReadingEvent.where(status: [:in_progress, :approved])

      results = []
      events.each do |event|
        next unless event_reading_day?(event, Date.yesterday)

        result = generate_daily_stats(event, Date.yesterday, force: false)
        results << {
          event_id: event.id,
          event_title: event.title,
          date: Date.yesterday,
          success: result[:success],
          error: result[:error]
        }
      end

      successful = results.select { |r| r[:success] }.count
      failed = results.count - successful

      Rails.logger.info "自动每日统计完成: 成功 #{successful} 个, 失败 #{failed} 个"

      {
        success: failed == 0,
        message: "自动统计完成",
        summary: {
          total_events: results.count,
          successful: successful,
          failed: failed,
          results: results
        }
      }
    end

    # 获取活动的每日统计历史
    def get_event_stats_history(event, days: 30)
      return { error: '活动不存在' } unless event

      stats = DailyFlowerStat.for_event(event)
                           .where(stats_date: (Date.current - days.days)..Date.current)
                           .order(stats_date: :desc)

      {
        event: event.as_json_for_api,
        period: "#{Date.current - days.days} 至 #{Date.current}",
        stats: stats.map(&:as_json_for_api)
      }
    end

    # 获取指定日期的排行榜数据
    def get_leaderboard_for_date(event, date = Date.yesterday)
      return { error: '活动不存在' } unless event

      stat = DailyFlowerStat.find_by(reading_event: event, stats_date: date)
      return { error: '该日期无统计数据' } unless stat

      {
        success: true,
        date: date,
        event: event.as_json_for_api,
        leaderboard: stat.leaderboard,
        top_three: stat.top_three,
        statistics: {
          total_flowers_given: stat.total_flowers_given,
          total_participants: stat.total_participants,
          total_givers: stat.total_givers,
          share_count: stat.share_count
        },
        share_info: {
          image_url: stat.share_image_url || stat.generate_share_image_url,
          text: stat.share_text_for_wechat,
          share_count: stat.share_count
        },
        generated_at: stat.generated_at
      }
    end

    # 增加分享次数并返回分享信息
    def increment_share_count(event, date = Date.yesterday)
      stat = DailyFlowerStat.find_by(reading_event: event, stats_date: date)
      return { error: '统计数据不存在' } unless stat

      stat.increment_share_count!

      {
        success: true,
        share_count: stat.share_count,
        share_info: {
          image_url: stat.share_image_url || stat.generate_share_image_url,
          text: stat.share_text_for_wechat
        }
      }
    end

    # 生成分享图片URL（占位符）
    def generate_share_image_url(event, date)
      # 这里可以集成第三方图片生成服务
      timestamp = Time.current.to_i
      base_url = Rails.application.config.base_url || 'http://localhost:3000'
      "#{base_url}/share-images/daily-flower-stats/#{event.id}/#{date}?t=#{timestamp}"
    end

    private

    # 获取指定日期的小红花数据
    def get_flowers_for_date(event, date)
      # 获取指定日期范围内的小红花
      start_time = date.beginning_of_day
      end_time = date.end_of_day

      Flower.joins(:recipient)
            .joins(check_in: :event_enrollment)
            .where(event_enrollments: { reading_event_id: event.id })
            .where('flowers.created_at >= ? AND flowers.created_at <= ?', start_time, end_time)
            .includes(:giver, :recipient, :check_in)
    end

    # 生成排行榜
    def generate_leaderboard(flowers)
      # 按接收者分组统计小红花数量
      flower_stats = flowers.group_by(&:recipient_id)
                           .map do |recipient_id, user_flowers|
        recipient = User.find_by(id: recipient_id)
        next unless recipient

        {
          user_id: recipient_id,
          nickname: recipient.nickname,
          avatar_url: recipient.avatar_url,
          total_flowers: user_flowers.sum(&:amount),
          flowers_received: user_flowers.count,
          flowers_given: flowers.where(giver_id: recipient_id).count,
          check_ins: user_flowers.map(&:check_in).uniq.count,
          last_flower_at: user_flowers.maximum(:created_at)
        }
      end
                           .compact
                           .sort_by { |entry| -entry[:total_flowers] }
                           .each_with_index.map { |entry, index| entry.merge(rank: index + 1) }
    end

    # 计算统计数据
    def calculate_statistics(flowers, event, date)
      {
        total_flowers_given: flowers.sum(&:amount),
        total_participants: flowers.map(&:recipient_id).uniq.count,
        total_givers: flowers.map(&:giver_id).uniq.count,
        average_flowers_per_user: flowers.count > 0 ? (flowers.sum(&:amount).to_f / flowers.map(&:recipient_id).uniq.count).round(2) : 0
      }
    end

    # 生成分享文案
    def generate_share_text(event, date, leaderboard)
      return '' if leaderboard.empty?

      text = "🌸 #{event.title} #{date.strftime('%m月%d日')}小红花排行榜\n\n"
      text += "🏆 今日小红花TOP3：\n"

      leaderboard.first(3).each_with_index do |entry, index|
        emoji = ['🥇', '🥈', '🥉'][index]
        text += "#{emoji} #{entry[:nickname]} - #{entry[:total_flowers]}朵\n"
      end

      text += "\n💝 #{leaderboard.first[:total_flowers]}朵小红花来自#{leaderboard.count}位小伙伴的鼓励！"
      text += "\n#读书打卡 #小红花 #共读成长"

      text
    end

    # 检查指定日期是否是活动阅读日
    def event_reading_day?(event, date)
      return false unless event.start_date && event.end_date
      return false if date < event.start_date || date > event.end_date

      # 如果设置周末休息，跳过周末
      if event.weekend_rest && (date.saturday? || date.sunday?)
        return false
      end

      true
    end
  end
end