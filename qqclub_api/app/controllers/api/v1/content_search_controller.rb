class Api::V1::ContentSearchController < Api::V1::BaseController
  before_action :authenticate_user!

  # GET /api/v1/content_search
  # 内容搜索
  def index
    search_params = build_search_params

    # 执行搜索
    result = ContentSearchService.search(search_params)

    render_success(
      data: result.to_h,
      message: '搜索完成'
    )
    log_api_call('content_search#index')
  rescue => e
    render_error(
      message: '搜索失败',
      errors: [e.message],
      code: 'SEARCH_ERROR'
    )
  end

  # GET /api/v1/content_search/advanced
  # 高级搜索
  def advanced
    search_params = build_search_params

    result = ContentSearchService.advanced_search(search_params)

    render_success(
      data: {
        check_ins: result[:check_ins].map(&:to_search_result_h),
        options: result[:options]
      },
      message: '高级搜索完成'
    )
    log_api_call('content_search#advanced')
  rescue => e
    render_error(
      message: '高级搜索失败',
      errors: [e.message],
      code: 'ADVANCED_SEARCH_ERROR'
    )
  end

  # GET /api/v1/content_search/suggestions
  # 搜索建议
  def suggestions
    query = params[:q]&.strip

    if query.blank?
      render_error(
        message: '请输入搜索关键词',
        code: 'EMPTY_QUERY',
        status: :unprocessable_entity
      )
      return
    end

    suggestions = generate_search_suggestions(query)

    render_success(
      data: {
        query: query,
        suggestions: suggestions
      },
      message: '搜索建议生成成功'
    )
  rescue => e
    render_error(
      message: '生成搜索建议失败',
      errors: [e.message],
      code: 'SUGGESTIONS_ERROR'
    )
  end

  # GET /api/v1/content_search/popular_keywords
  # 热门关键词
  def popular_keywords
    days = safe_integer_param(params[:days]) || 30
    limit = safe_integer_param(params[:limit]) || 20

    keywords = ContentSearchService.popular_keywords(limit, days)

    render_success(
      data: {
        keywords: keywords,
        period: "#{days}天",
        updated_at: Time.current
      },
      message: '热门关键词获取成功'
    )
  rescue => e
    render_error(
      message: '获取热门关键词失败',
      errors: [e.message],
      code: 'POPULAR_KEYWORDS_ERROR'
    )
  end

  # GET /api/v1/content_search/trends
  # 搜索趋势
  def trends
    days = safe_integer_param(params[:days]) || 7

    trends = ContentSearchService.search_trends(days)

    render_success(
      data: {
        trends: trends,
        period: "#{days}天"
      },
      message: '搜索趋势获取成功'
    )
  rescue => e
    render_error(
      message: '获取搜索趋势失败',
      errors: [e.message],
      code: 'TRENDS_ERROR'
    )
  end

  # GET /api/v1/content_search/related/:check_in_id
  # 相关内容推荐
  def related
    check_in_id = safe_integer_param(params[:check_in_id])

    unless check_in_id
      render_error(
        message: '打卡ID不能为空',
        code: 'INVALID_CHECK_IN_ID',
        status: :unprocessable_entity
      )
      return
    end

    check_in = CheckIn.find_by(id: check_in_id)

    unless check_in
      render_error(
        message: '打卡记录不存在',
        code: 'CHECK_IN_NOT_FOUND',
        status: :not_found
      )
      return
    end

    # 检查权限（只有活动参与者可以查看相关内容）
    unless current_user.enrolled?(check_in.reading_event) ||
           check_in.reading_event.leader == current_user ||
           current_user.can_approve_events?
      render_error(
        message: '权限不足',
        code: 'FORBIDDEN',
        status: :forbidden
      )
      return
    end

    limit = safe_integer_param(params[:limit]) || 5
    related_check_ins = ContentSearchService.recommend_related(check_in, limit)

    render_success(
      data: {
        original_check_in: check_in.to_search_result_h,
        related_check_ins: related_check_ins.map(&:to_search_result_h),
        limit: limit
      },
      message: '相关内容推荐成功'
    )
    log_api_call('content_search#related')
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '打卡记录不存在',
      code: 'CHECK_IN_NOT_FOUND',
      status: :not_found
    )
  rescue => e
    render_error(
      message: '获取相关内容失败',
      errors: [e.message],
      code: 'RELATED_CONTENT_ERROR'
    )
  end

  # GET /api/v1/content_search/facets
  # 搜索统计
  def facets
    search_params = build_search_params.reject { |_, v| v.blank? }

    if search_params.empty?
      render_error(
        message: '请提供搜索条件',
        code: 'EMPTY_SEARCH_PARAMS',
        status: :unprocessable_entity
      )
      return
    end

    result = ContentSearchService.search(search_params)

    render_success(
      data: {
        facets: result.facets,
        total_count: result.total_count,
        search_params: search_params
      },
      message: '搜索统计获取成功'
    )
  rescue => e
    render_error(
      message: '获取搜索统计失败',
      errors: [e.message],
      code: 'FACETS_ERROR'
    )
  end

  # POST /api/v1/content_search/save_search
  # 保存搜索历史
  def save_search
    query = params[:query]&.strip
    search_type = params[:search_type] || 'basic'

    if query.blank?
      render_error(
        message: '搜索内容不能为空',
        code: 'EMPTY_QUERY',
        status: :unprocessable_entity
      )
      return
    end

    # 这里可以实现搜索历史保存逻辑
    # 例如：保存到用户的搜索历史记录中

    render_success(
      message: '搜索历史保存成功'
    )
    log_api_call('content_search#save_search')
  rescue => e
    render_error(
      message: '保存搜索历史失败',
      errors: [e.message],
      code: 'SAVE_SEARCH_ERROR'
    )
  end

  # GET /api/v1/content_search/history
  # 搜索历史
  def history
    limit = safe_integer_param(params[:limit]) || 10

    # 这里可以实现获取用户搜索历史的逻辑
    # 暂时返回空数组
    history_items = []

    render_success(
      data: {
        history: history_items,
        limit: limit
      },
      message: '搜索历史获取成功'
    )
  rescue => e
    render_error(
      message: '获取搜索历史失败',
      errors: [e.message],
      code: 'SEARCH_HISTORY_ERROR'
    )
  end

  private

  # 构建搜索参数
  def build_search_params
    params.permit(
      :query, :event_id, :user_id, :date_from, :date_to, :status,
      :quality_min, :quality_max, :keywords, :sort_by, :sort_direction,
      :page, :per_page
    ).to_h
  end

  # 生成搜索建议
  def generate_search_suggestions(query)
    suggestions = []

    # 拼写检查建议
    suggestions.concat(spell_check_suggestions(query))

    # 热门关键词建议
    popular_keywords = ContentSearchService.popular_keywords(10, 7)
    matching_keywords = popular_keywords.keys.select { |keyword| keyword.include?(query) }
    suggestions.concat(matching_keywords.map { |keyword| "#{keyword} (#{popular_keywords[keyword]}次)" })

    # 相关搜索建议
    suggestions.concat(related_search_suggestions(query))

    suggestions.uniq.first(10)
  end

  # 拼写检查建议
  def spell_check_suggestions(query)
    # 简化的拼写检查实现
    # 实际应用中可以使用更复杂的算法

    suggestions = []
    popular_keywords = ContentSearchService.popular_keywords(50, 30)

    # 简单的编辑距离计算
    popular_keywords.keys.each do |keyword|
      distance = levenshtein_distance(query.downcase, keyword.downcase)
      if distance <= 2 && distance > 0
        suggestions << keyword
      end
    end

    suggestions.first(5)
  end

  # 相关搜索建议
  def related_search_suggestions(query)
    # 基于用户历史和热门搜索生成相关建议
    suggestions = []

    # 可以添加更多相关搜索逻辑
    suggestions
  end

  # 计算编辑距离（简化版）
  def levenshtein_distance(str1, str2)
    matrix = Array.new(str1.length + 1) { Array.new(str2.length + 1) }

    (0..str1.length).each { |i| matrix[i][0] = i }
    (0..str2.length).each { |j| matrix[0][j] = j }

    (1..str1.length).each do |i|
      (1..str2.length).each do |j|
        cost = str1[i-1] == str2[j-1] ? 0 : 1
        matrix[i][j] = [
          matrix[i-1][j] + 1,     # deletion
          matrix[i][j-1] + 1,     # insertion
          matrix[i-1][j-1] + cost # substitution
        ].min
      end
    end

    matrix[str1.length][str2.length]
  end

  # 辅助方法
  def safe_integer_param(param)
    return nil if param.blank?
    Integer(param)
  rescue ArgumentError, TypeError
    nil
  end
end