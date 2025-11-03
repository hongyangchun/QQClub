# 内容搜索服务
# 提供打卡内容的全文搜索、高级搜索和推荐功能
class ContentSearchService
  include ActionView::Helpers::SanitizeHelper

  class SearchOptions
    attr_accessor :query, :event_id, :user_id, :date_from, :date_to, :status,
                  :quality_min, :quality_max, :keywords, :sort_by, :sort_direction,
                  :page, :per_page

    def initialize(params = {})
      @query = params[:query]&.strip
      @event_id = params[:event_id]
      @user_id = params[:user_id]
      @date_from = parse_date(params[:date_from])
      @date_to = parse_date(params[:date_to])
      @status = params[:status]
      @quality_min = params[:quality_min]&.to_i
      @quality_max = params[:quality_max]&.to_i
      @keywords = params[:keywords]&.split(',')&.map(&:strip)
      @sort_by = params[:sort_by] || 'relevance'
      @sort_direction = params[:sort_direction] || 'desc'
      @page = params[:page]&.to_i || 1
      @per_page = params[:per_page]&.to_i || 20
    end

    private

    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string)
    rescue ArgumentError, TypeError
      nil
    end
  end

  class SearchResult
    attr_accessor :check_ins, :total_count, :total_pages, :current_page,
                  :suggestions, :search_time, :facets

    def initialize
      @check_ins = []
      @total_count = 0
      @total_pages = 0
      @current_page = 1
      @suggestions = []
      @search_time = 0
      @facets = {}
    end

    def to_h
      {
        check_ins: check_ins.map(&:to_search_result_h),
        pagination: {
          current_page: current_page,
          total_pages: total_pages,
          total_count: total_count,
          per_page: search_options&.per_page || 20
        },
        suggestions: suggestions,
        search_time: search_time,
        facets: facets
      }
    end

    def search_options=(options)
      @search_options = options
    end

    attr_reader :search_options
  end

  class << self
    # 主要搜索方法
    def search(params = {})
      options = SearchOptions.new(params)
      result = SearchResult.new
      result.search_options = options

      start_time = Time.current

      # 执行搜索
      check_ins = perform_search(options)

      # 统计总数
      total_count = count_search_results(options)

      # 分页
      paginated_check_ins = check_ins.includes(:user, :reading_schedule, :flowers)
                                  .limit(options.per_page)
                                  .offset((options.page - 1) * options.per_page)

      # 计算搜索建议
      suggestions = generate_suggestions(options)

      # 生成搜索统计
      facets = generate_facets(check_ins)

      end_time = Time.current

      result.check_ins = paginated_check_ins.to_a
      result.total_count = total_count
      result.total_pages = (total_count.to_f / options.per_page).ceil
      result.current_page = options.page
      result.suggestions = suggestions
      result.search_time = ((end_time - start_time) * 1000).round(2)
      result.facets = facets

      result
    end

    # 高级搜索
    def advanced_search(params = {})
      # 高级搜索支持更复杂的条件组合
      options = SearchOptions.new(params)

      # 构建复杂查询
      check_ins = build_advanced_query(options)

      # 应用排序
      check_ins = apply_sorting(check_ins, options)

      {
        check_ins: check_ins.includes(:user, :reading_schedule),
        options: options
      }
    end

    # 推荐相关内容
    def recommend_related(check_in, limit = 5)
      # 基于内容相似性推荐相关打卡
      keywords = check_in.keywords(10)

      related_check_ins = CheckIn.joins(:reading_schedule)
                               .where.not(id: check_in.id)
                               .where(reading_schedules: { reading_event_id: check_in.reading_event_id })

      # 基于关键词匹配
      if keywords.any?
        keyword_conditions = keywords.map { |keyword| "check_ins.content LIKE ?" }.join(' OR ')
        keyword_values = keywords.map { |keyword| "%#{keyword}%" }

        related_check_ins = related_check_ins.where(keyword_conditions, *keyword_values)
      end

      # 按质量和时间排序
      related_check_ins.order('created_at DESC').limit(limit)
    end

    # 热门关键词
    def popular_keywords(limit = 20, days = 30)
      start_date = days.days.ago.to_date

      # 简化的关键词统计（实际应用中可以使用更复杂的算法）
      recent_check_ins = CheckIn.where('created_at >= ?', start_date)

      keyword_counts = Hash.new(0)

      recent_check_ins.find_each do |check_in|
        check_in.keywords(5).each do |keyword|
          keyword_counts[keyword] += 1
        end
      end

      keyword_counts.sort_by { |_, count| -count }.first(limit).to_h
    end

    # 搜索趋势
    def search_trends(days = 7)
      start_date = days.days.ago.to_date

      daily_stats = CheckIn.where('created_at >= ?', start_date)
                         .group('DATE(created_at)')
                         .count

      (0...days).map do |i|
        date = (Date.today - days + 1 + i)
        {
          date: date,
          count: daily_stats[date] || 0
        }
      end
    end

    private

    # 执行基础搜索
    def perform_search(options)
      query = CheckIn.joins(:user, :reading_schedule)

      # 文本搜索
      if options.query.present?
        query = apply_text_search(query, options.query)
      end

      # 活动筛选
      if options.event_id.present?
        query = query.where(reading_schedules: { reading_event_id: options.event_id })
      end

      # 用户筛选
      if options.user_id.present?
        query = query.where(user_id: options.user_id)
      end

      # 日期范围筛选
      if options.date_from.present?
        query = query.where('check_ins.created_at >= ?', options.date_from.beginning_of_day)
      end

      if options.date_to.present?
        query = query.where('check_ins.created_at <= ?', options.date_to.end_of_day)
      end

      # 状态筛选
      if options.status.present?
        query = query.where(status: options.status)
      end

      # 质量分数筛选
      if options.quality_min.present?
        # 这里需要添加quality_score字段的计算逻辑
        # 暂时使用简化版本
        query = query.where('word_count >= ?', options.quality_min * 10)
      end

      if options.quality_max.present?
        query = query.where('word_count <= ?', options.quality_max * 10)
      end

      # 关键词筛选
      if options.keywords.present?
        keyword_conditions = options.keywords.map { |keyword| "check_ins.content LIKE ?" }.join(' OR ')
        keyword_values = options.keywords.map { |keyword| "%#{keyword}%" }

        query = query.where(keyword_conditions, *keyword_values)
      end

      query
    end

    # 应用文本搜索
    def apply_text_search(query, search_query)
      # 简单的全文搜索实现
      # 实际应用中可以使用PostgreSQL的全文搜索或Elasticsearch

      search_terms = search_query.split(/\s+/).reject(&:blank?)

      search_terms.each do |term|
        query = query.where('check_ins.content LIKE ?', "%#{term}%")
      end

      query
    end

    # 统计搜索结果数量
    def count_search_results(options)
      perform_search(options).count
    end

    # 应用排序
    def apply_sorting(query, options)
      case options.sort_by
      when 'relevance'
        # 相关性排序（简化版）
        query.order('created_at DESC')
      when 'created_at'
        direction = options.sort_direction.upcase == 'ASC' ? 'ASC' : 'DESC'
        query.order("created_at #{direction}")
      when 'word_count'
        direction = options.sort_direction.upcase == 'ASC' ? 'ASC' : 'DESC'
        query.order("word_count #{direction}")
      when 'flowers_count'
        query = query.left_joins(:flowers)
                 .group('check_ins.id')
                 .order("COUNT(flowers.id) #{options.sort_direction.upcase}")
      else
        query.order('created_at DESC')
      end
    end

    # 生成搜索建议
    def generate_suggestions(options)
      suggestions = []

      # 如果没有结果，提供拼写建议
      if options.query.present? && options.query.length > 2
        # 简化的拼写检查
        suggestions << "尝试使用更简短的关键词"
        suggestions << "检查是否有拼写错误"
      end

      # 日期范围建议
      if options.date_from.blank? || options.date_to.blank?
        suggestions << "添加日期范围以缩小搜索结果"
      end

      # 关键词建议
      popular_keywords = popular_keywords(5)
      if popular_keywords.any?
        suggestions << "热门关键词：#{popular_keywords.keys.first(3).join(', ')}"
      end

      suggestions
    end

    # 生成搜索统计
    def generate_facets(check_ins)
      facets = {}

      # 按状态统计
      status_facet = check_ins.group(:status).count
      facets[:status] = status_facet.transform_keys { |status| status.to_s }

      # 按日期统计
      date_facet = check_ins.group('DATE(created_at)').count
      facets[:dates] = date_facet

      # 按用户统计（前10名）
      user_facet = check_ins.joins(:user).group('users.nickname').count
                            .sort_by { |_, count| -count }.first(10).to_h
      facets[:users] = user_facet

      facets
    end

    # 构建高级查询
    def build_advanced_query(options)
      query = CheckIn.joins(:user, :reading_schedule)

      # 实现更复杂的查询逻辑
      # 例如：OR条件、NOT条件、短语搜索等

      query
    end
  end
end

# 扩展CheckIn模型以支持搜索结果格式化
class CheckIn
  def to_search_result_h
    {
      id: id,
      content_preview: content_preview(150),
      formatted_content: formatted_content(length: 150),
      user: {
        id: user.id,
        nickname: user.nickname,
        avatar_url: user.avatar_url
      },
      reading_event: {
        id: reading_event.id,
        title: reading_event.title
      },
      reading_schedule: {
        id: reading_schedule.id,
        date: reading_schedule.date,
        day_number: reading_schedule.day_number
      },
      word_count: word_count,
      status: status,
      submitted_at: submitted_at,
      flowers_count: flowers_count,
      quality_score: quality_score,
      keywords: keywords(5),
      reading_time: reading_time_estimate
    }
  end
end