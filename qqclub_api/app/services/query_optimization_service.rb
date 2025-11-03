# frozen_string_literal: true

# 查询优化服务
# 提供高性能的数据库查询方法，减少N+1查询和优化复杂查询
class QueryOptimizationService
  class << self
    # 批量预加载关联数据，避免N+1查询
    # @param records [Array] ActiveRecord记录数组
    # @param includes [Array] 需要预加载的关联
    # @return [Array] 预加载后的记录
    def preload_associations(records, includes)
      return records if records.empty?

      # 使用ActiveRecord的preload方法避免N+1查询
      if records.first.is_a?(Class)
        # 如果是模型类，使用includes
        records.includes(includes)
      else
        # 如果是记录数组，使用preload
        ActiveRecord::Associations::Preloader.new.preload(records, includes)
        records
      end
    end

    # 优化的用户查询，包含常用关联
    # @param scope [ActiveRecord::Relation] 基础查询范围
    # @param options [Hash] 查询选项
    # @return [ActiveRecord::Relation] 优化后的查询
    def optimized_user_query(scope = User.all, options = {})
      includes = [:created_events, :event_enrollments, :check_ins, :comments]
      includes << :received_flowers if options[:include_flowers]
      includes << :flower_certificates if options[:include_certificates]

      scope.includes(includes)
    end

    # 优化的活动查询，包含统计信息
    # @param scope [ActiveRecord::Relation] 基础查询范围
    # @param options [Hash] 查询选项
    # @return [ActiveRecord::Relation] 优化后的查询
    def optimized_event_query(scope = ReadingEvent.all, options = {})
      includes = [:leader, :event_enrollments, :reading_schedules]
      includes << :check_ins if options[:include_check_ins]
      includes << :flowers if options[:include_flowers]

      query = scope.includes(includes)

      # 如果需要统计数据，使用子查询而不是JOIN
      if options[:include_stats]
        query = query.select(
          'reading_events.*',
          '(SELECT COUNT(*) FROM event_enrollments WHERE event_enrollments.reading_event_id = reading_events.id AND event_enrollments.status = \'enrolled\') as enrolled_count',
          '(SELECT COUNT(*) FROM check_ins JOIN reading_schedules ON check_ins.reading_schedule_id = reading_schedules.id WHERE reading_schedules.reading_event_id = reading_events.id) as check_ins_count',
          '(SELECT COUNT(*) FROM flowers JOIN check_ins ON flowers.check_in_id = check_ins.id JOIN reading_schedules ON check_ins.reading_schedule_id = reading_schedules.id WHERE reading_schedules.reading_event_id = reading_events.id) as flowers_count'
        )
      end

      query
    end

    # 优化的打卡查询，包含内容分析
    # @param scope [ActiveRecord::Relation] 基础查询范围
    # @param options [Hash] 查询选项
    # @return [ActiveRecord::Relation] 优化后的查询
    def optimized_check_in_query(scope = CheckIn.all, options = {})
      includes = [:user, :reading_schedule, :enrollment]
      includes << :flowers if options[:include_flowers]
      includes << :comments if options[:include_comments]
      includes << :reading_event if options[:include_event]

      scope.includes(includes)
    end

    # 优化的通知查询，优先显示未读通知
    # @param user [User] 用户对象
    # @param options [Hash] 查询选项
    # @return [ActiveRecord::Relation] 优化后的查询
    def optimized_notification_query(user, options = {})
      query = user.received_notifications

      # 按未读状态和创建时间排序，未读通知优先
      query = query.order(read: :asc, created_at: :desc)

      # 包含关联数据
      includes = [:actor]
      includes << :notifiable if options[:include_notifiable]
      query = query.includes(includes)

      query
    end

    # 批量查询优化 - 使用IN查询而不是多次单独查询
    # @param model_class [Class] ActiveRecord模型类
    # @param ids [Array] ID数组
    # @param includes [Array] 需要预加载的关联
    # @return [Array] 查询结果
    def batch_find_by_ids(model_class, ids, includes = [])
      return [] if ids.empty?

      # 分批处理，避免IN子句过长
      batch_size = 1000
      results = []

      ids.each_slice(batch_size) do |batch_ids|
        query = model_class.where(id: batch_ids)
        query = query.includes(includes) if includes.any?
        results.concat(query.to_a)
      end

      # 按原始ID顺序排序
      id_index = ids.each_with_index.to_h
      results.sort_by { |record| id_index[record.id] }
    end

    # 优化的排行榜查询，使用窗口函数提高性能
    # @param model_class [Class] 模型类
    # @param count_column [String] 计数字段名
    # @param limit [Integer] 返回记录数限制
    # @param includes [Array] 需要预加载的关联
    # @return [Array] 排行榜数据
    def optimized_leaderboard_query(model_class, count_column, limit = 10, includes = [])
      # 使用窗口函数的子查询（如果数据库支持）
      if database_supports_window_functions?
        sql = <<~SQL
          SELECT *,
                 DENSE_RANK() OVER (ORDER BY #{count_column} DESC, created_at ASC) as rank
          FROM #{model_class.table_name}
          ORDER BY #{count_column} DESC, created_at ASC
          LIMIT ?
        SQL

        records = model_class.find_by_sql([sql, limit])
      else
        # 回退到普通查询
        records = model_class.order("#{count_column} DESC, created_at ASC")
                               .limit(limit)
                               .to_a

        # 手动计算排名
        records.each_with_index do |record, index|
          record.define_singleton_method(:rank) { index + 1 }
        end
      end

      # 预加载关联数据
      if includes.any?
        ActiveRecord::Associations::Preloader.new.preload(records, includes)
      end

      records
    end

    # 优化的计数查询，使用缓存避免重复计算
    # @param query [ActiveRecord::Relation] 查询对象
    # @param cache_key [String] 缓存键
    # @param cache_ttl [Integer] 缓存时间（秒）
    # @return [Integer] 计数结果
    def optimized_count_query(query, cache_key = nil, cache_ttl = 5.minutes)
      if cache_key && Rails.cache.respond_to?(:fetch)
        Rails.cache.fetch(cache_key, expires_in: cache_ttl) do
          query.count
        end
      else
        query.count
      end
    end

    # 优化的存在性查询，使用EXISTS而不是COUNT
    # @param query [ActiveRecord::Relation] 查询对象
    # @return [Boolean] 是否存在记录
    def optimized_exists_query(query)
      query.exists?
    end

    # 优化的分页查询，使用cursor-based分页提高性能
    # @param scope [ActiveRecord::Relation] 基础查询范围
    # @param cursor [Integer] 游标位置
    # @param limit [Integer] 每页记录数
    # @param order_column [String] 排序字段
    # @return [Array] 分页结果和下一页游标
    def cursor_paginated_query(scope, cursor: nil, limit: 20, order_column: 'id')
      query = scope.order(order_column => :asc).limit(limit + 1)

      if cursor
        query = query.where("#{order_column} > ?", cursor)
      end

      records = query.to_a

      has_next = records.length > limit
      next_cursor = has_next ? records.last.send(order_column) : nil

      records = records.first(limit)

      {
        records: records,
        next_cursor: next_cursor,
        has_next: has_next
      }
    end

    # 批量插入优化，使用批量插入减少数据库往返
    # @param model_class [Class] 模型类
    # @param attributes_array [Array] 属性数组
    # @param batch_size [Integer] 批次大小
    # @return [Array] 创建的记录
    def batch_insert(model_class, attributes_array, batch_size = 1000)
      return [] if attributes_array.empty?

      created_records = []

      attributes_array.each_slice(batch_size) do |batch|
        records = model_class.insert_all(batch, returning: true)
        created_records.concat(records)
      end

      created_records
    end

    # 优化的统计查询，使用数据库聚合函数
    # @param model_class [Class] 模型类
    # @param group_column [String] 分组字段
    # @param aggregations [Hash] 聚合配置
    # @return [Array] 统计结果
    def optimized_aggregation_query(model_class, group_column, aggregations)
      query = model_class.group(group_column)

      aggregations.each do |alias_name, aggregation|
        case aggregation[:type]
        when :count
          query = query.select("#{group_column}, COUNT(*) as #{alias_name}")
        when :sum
          query = query.select("#{group_column}, SUM(#{aggregation[:column]}) as #{alias_name}")
        when :avg
          query = query.select("#{group_column}, AVG(#{aggregation[:column]}) as #{alias_name}")
        when :max
          query = query.select("#{group_column}, MAX(#{aggregation[:column]}) as #{alias_name}")
        when :min
          query = query.select("#{group_column}, MIN(#{aggregation[:column]}) as #{alias_name}")
        end
      end

      query.to_a
    end

    private

    # 检查数据库是否支持窗口函数
    def database_supports_window_functions?
      case ActiveRecord::Base.connection.adapter_name.downcase
      when 'postgresql', 'mysql'
        true
      when 'sqlite'
        # SQLite 3.25+ 支持窗口函数
        sqlite_version = ActiveRecord::Base.connection.select_value("SELECT sqlite_version()")
        Gem::Version.new(sqlite_version) >= Gem::Version.new('3.25.0')
      else
        false
      end
    end

    # 生成查询的缓存键
    def generate_cache_key(model_class, query_params = {})
      key_parts = [
        model_class.name.downcase,
        'query',
        Digest::MD5.hexdigest(query_params.to_json)
      ]
      key_parts.join('_')
    end
  end
end