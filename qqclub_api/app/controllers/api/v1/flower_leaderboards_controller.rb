class Api::V1::FlowerLeaderboardsController < Api::V1::BaseController
  before_action :authenticate_user!

  # GET /api/v1/flower_leaderboards
  # 获取小红花排行榜
  def index
    type = params[:type] || 'received'
    period = safe_integer_param(params[:period]) || 30
    limit = safe_integer_param(params[:limit]) || 20

    # 验证参数
    valid_types = %w[received given popular_check_ins generous_givers]
    unless valid_types.include?(type)
      render_error(
        message: '无效的排行榜类型',
        code: 'INVALID_TYPE',
        status: :unprocessable_entity
      )
      return
    end

    if period < 1 || period > 365
      render_error(
        message: '统计时间范围必须在1-365天之间',
        code: 'INVALID_PERIOD',
        status: :unprocessable_entity
      )
      return
    end

    if limit < 1 || limit > 100
      render_error(
        message: '显示数量必须在1-100之间',
        code: 'INVALID_LIMIT',
        status: :unprocessable_entity
      )
      return
    end

    # 获取排行榜数据
    leaderboard = FlowerStatisticsService.get_flower_leaderboard(type, period, limit)

    # 格式化响应数据
    formatted_leaderboard = case type.to_sym
                           when :received
                              format_user_leaderboard(leaderboard)
                           when :given
                              format_user_leaderboard(leaderboard)
                           when :popular_check_ins
                              format_check_in_leaderboard(leaderboard)
                           when :generous_givers
                              format_user_leaderboard(leaderboard)
                           else
                              []
                           end

    render_success(
      data: {
        leaderboard_type: type,
        period: period,
        limit: limit,
        leaderboard: formatted_leaderboard
      },
      message: '排行榜获取成功'
    )
    log_api_call('flower_leaderboards#index')
  rescue => e
    render_error(
      message: '获取排行榜失败',
      errors: [e.message],
      code: 'LEADERBOARD_ERROR'
    )
  end

  # GET /api/v1/flower_leaderboards/trends
  # 获取小红花趋势数据
  def trends
    days = safe_integer_param(params[:days]) || 30

    if days < 1 || days > 90
      render_error(
        message: '统计时间范围必须在1-90天之间',
        code: 'INVALID_PERIOD',
        status: :unprocessable_entity
      )
      return
    end

    trends = FlowerStatisticsService.get_flower_trends(days)

    render_success(
      data: {
        period: "#{days}天",
        trends: trends,
        summary: calculate_trends_summary(trends)
      },
      message: '趋势数据获取成功'
    )
    log_api_call('flower_leaderboards#trends')
  rescue => e
    render_error(
      message: '获取趋势数据失败',
      errors: [e.message],
      code: 'TRENDS_ERROR'
    )
  end

  # GET /api/v1/flower_leaderboards/statistics
  # 获取小红花统计
  def statistics
    days = safe_integer_param(params[:days]) || 30
    type = params[:type] # 'user' 或 'event'
    id = safe_integer_param(params[:id])

    if days < 1 || days > 365
      render_error(
        message: '统计时间范围必须在1-365天之间',
        code: 'INVALID_PERIOD',
        status: :unprocessable_entity
      )
      return
    end

    data = case type
            when 'user'
              get_user_statistics(id, days)
            when 'event'
              get_event_statistics(id, days)
            when 'incentive'
              FlowerStatisticsService.get_incentive_statistics(days)
            else
              FlowerStatisticsService.get_incentive_statistics(days)
            end

    if data.nil?
      render_error(
        message: '无效的统计类型或ID',
        code: 'INVALID_TYPE_OR_ID',
        status: :unprocessable_entity
      )
      return
    end

    render_success(
      data: data,
      message: '统计数据获取成功'
    )
    log_api_call('flower_leaderboards#statistics')
  rescue => e
    render_error(
      message: '获取统计数据失败',
      errors: [e.message],
      code: 'STATISTICS_ERROR'
    )
  end

  # GET /api/v1/flower_leaderboards/suggestions
  # 获取小红花发放建议
  def suggestions
    limit = safe_integer_param(params[:limit]) || 5

    if limit < 1 || limit > 20
      render_error(
        message: '建议数量必须在1-20之间',
        code: 'INVALID_LIMIT',
        status: :unprocessable_entity
      )
      return
    end

    suggestions = FlowerStatisticsService.get_flower_suggestions(current_user, limit)

    formatted_suggestions = suggestions.map do |suggestion|
      case suggestion[:type]
      when :check_in
        {
          id: suggestion[:check_in].id,
          type: 'check_in',
          title: suggestion[:check_in].content_preview(100),
          author: {
            id: suggestion[:check_in].user.id,
            nickname: suggestion[:check_in].user.nickname,
            avatar_url: suggestion[:check_in].user.avatar_url
          },
          created_at: suggestion[:check_in].created_at,
          flowers_count: suggestion[:check_in].flowers_count,
          reason: suggestion[:reason],
          priority: suggestion[:priority]
        }
      when :user
        {
          id: suggestion[:user].id,
          type: 'user',
          nickname: suggestion[:user].nickname,
          avatar_url: suggestion[:user].avatar_url,
          reason: suggestion[:reason],
          priority: suggestion[:priority]
        }
      end
    end

    render_success(
      data: {
        suggestions: formatted_suggestions,
        limit: limit,
        user_id: current_user.id
      },
      message: '发放建议获取成功'
    )
    log_api_call('flower_leaderboards#suggestions')
  rescue => e
    render_error(
      message: '获取发放建议失败',
      errors: [e.message],
      code: 'SUGGESTIONS_ERROR'
    )
  end

  # GET /api/v1/flower_leaderboards/my_ranking
  # 获取当前用户的排名
  def my_ranking
    period = safe_integer_param(params[:period]) || 30
    type = params[:type] || 'received'

    if period < 1 || period > 365
      render_error(
        message: '统计时间范围必须在1-365天之间',
        code: 'INVALID_PERIOD',
        status: :unprocessable_entity
      )
      return
    end

    # 获取排行榜
    leaderboard = FlowerStatisticsService.get_flower_leaderboard(type, period, 1000)

    # 查找当前用户的排名
    my_ranking = case type.to_sym
                  when :received
                    leaderboard.index { |user| user[:id] == current_user.id }
                  when :given
                    leaderboard.index { |user| user[:id] == current_user.id }
                  else
                    nil
                  end

    my_stats = FlowerStatisticsService.get_user_flower_stats(current_user, period)

    render_success(
      data: {
        period: period,
        type: type,
        my_ranking: my_ranking ? my_ranking + 1 : nil, # 排名从1开始
        total_users: leaderboard.count,
        my_stats: my_stats,
        top_10: leaderboard.first(10).map { |user| user[:id] },
        percentage: calculate_ranking_percentage(my_ranking, leaderboard.count)
      },
      message: '个人排名获取成功'
    )
    log_api_call('flower_leaderboards#my_ranking')
  rescue => e
    render_error(
      message: '获取个人排名失败',
      errors: [e.message],
      code: 'MY_RANKING_ERROR'
    )
  end

  private

  def get_user_statistics(user_id, days)
    user = user_id ? User.find_by(id: user_id) : current_user
    return nil unless user

    FlowerStatisticsService.get_user_flower_stats(user, days)
  end

  def get_event_statistics(event_id, days)
    event = ReadingEvent.find_by(id: event_id)
    return nil unless event

    FlowerStatisticsService.get_event_flower_stats(event, days)
  end

  def format_user_leaderboard(leaderboard)
    leaderboard.map do |user|
      {
        id: user.id,
        nickname: user.nickname,
        avatar_url: user.avatar_url,
        total_flowers: user.total_flowers,
        rank: leaderboard.index(user) + 1
      }
    end
  end

  def format_check_in_leaderboard(leaderboard)
    leaderboard.map do |check_in|
      {
        id: check_in.id,
        content: check_in.content_preview(100),
        author: {
          id: check_in.user.id,
          nickname: check_in.user.nickname,
          avatar_url: check_in.user.avatar_url
        },
        created_at: check_in.created_at,
        flowers_count: check_in.flower_count,
        rank: leaderboard.index(check_in) + 1
      }
    end
  end

  def calculate_trends_summary(trends)
    total_flowers = trends.values.sum { |day| day[:total] }
    avg_flowers = trends.values.sum { |day| day[:total] }.to_f / [trends.count, 1].max
    max_flowers = trends.values.map { |day| day[:total] }.max || 0
    min_flowers = trends.values.map { |day| day[:total] }.min || 0

    {
      total_flowers: total_flowers,
      avg_flowers: avg_flowers.round(2),
      max_flowers: max_flowers,
      min_flowers: min_flowers,
      trend_days: trends.keys.count
    }
  end

  def calculate_ranking_percentage(rank, total_users)
    return 0 if rank.nil? || total_users == 0
    ((total_users - rank + 1).to_f / total_users * 100).round(2)
  end

  # 辅助方法
  def safe_integer_param(param)
    return nil if param.blank?
    Integer(param)
  rescue ArgumentError, TypeError
    nil
  end
end