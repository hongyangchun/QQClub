# frozen_string_literal: true

# 响应时间优化服务
# 提供多种优化技术来减少API响应时间
class ResponseOptimizationService
  class << self
    # 响应时间监控装饰器
    # @param operation_name [String] 操作名称
    # @param options [Hash] 选项
    # @yield 要监控的操作
    # @return [Object] 操作结果
    def with_response_time_monitoring(operation_name, options = {})
      start_time = Time.current
      request_id = RequestStore.store[:request_id] || SecureRandom.uuid

      begin
        # 设置请求ID到存储中
        RequestStore.store[:request_id] = request_id

        # 执行操作
        result = yield

        # 计算响应时间
        response_time = Time.current - start_time

        # 记录性能指标
        record_performance_metrics(operation_name, response_time, options, true)

        # 如果响应时间过长，记录警告
        if response_time > (options[:slow_threshold] || 2.0)
          Rails.logger.warn "慢查询警告: #{operation_name} 耗时 #{response_time.round(3)}s"
        end

        # 添加响应时间到响应头（如果有request_store）
        if RequestStore.store[:response_object]
          RequestStore.store[:response_object].headers['X-Response-Time'] = "#{response_time.round(3)}s"
          RequestStore.store[:response_object].headers['X-Request-ID'] = request_id
        end

        result

      rescue => e
        response_time = Time.current - start_time
        record_performance_metrics(operation_name, response_time, options, false, e)

        raise e
      end
    end

    # 预加载关联数据以避免N+1查询
    # @param records [Array] ActiveRecord记录数组
    # @param associations [Array] 需要预加载的关联
    # @return [Array] 预加载后的记录
    def preload_associations(records, associations)
      return records if records.empty? || associations.empty?

      # 使用ActiveRecord的preload方法
      ActiveRecord::Associations::Preloader.new.preload(records, associations)
      records
    end

    # 并行执行多个独立操作
    # @param operations [Array] 操作数组，每个元素为[操作名称, 操作块]
    # @return [Array] 所有操作的结果
    def parallel_execute(operations)
      return [] if operations.empty?

      # 使用线程池并行执行
      thread_pool = Concurrent::ThreadPoolExecutor.new(
        min_threads: 1,
        max_threads: [operations.length, 5].min
      )

      futures = operations.map do |operation_name, operation_block|
        Concurrent::Future.execute(executor: thread_pool) do
          start_time = Time.current
          begin
            result = operation_block.call
            {
              operation: operation_name,
              result: result,
              execution_time: Time.current - start_time,
              success: true
            }
          rescue => e
            {
              operation: operation_name,
              result: nil,
              execution_time: Time.current - start_time,
              success: false,
              error: e.message
            }
          end
        end
      end

      # 等待所有操作完成并收集结果
      results = futures.map(&:value)
      thread_pool.shutdown
      thread_pool.wait_for_termination(10)

      results
    end

    # 条件查询优化
    # @param model_class [Class] ActiveRecord模型类
    # @param conditions [Hash] 查询条件
    # @param options [Hash] 选项
    # @return [ActiveRecord::Relation] 优化后的查询
    def optimized_query(model_class, conditions, options = {})
      query = model_class.where(conditions)

      # 应用排序优化
      if options[:order]
        # 检查是否有合适的索引
        if has_index_for_order?(model_class, options[:order])
          query = query.order(options[:order])
        else
          Rails.logger.warn "缺少排序索引: #{model_class.name}.#{options[:order]}"
          query = query.order(options[:order]) # 仍然应用排序，但记录警告
        end
      end

      # 应用分页限制
      if options[:limit]
        query = query.limit(options[:limit])
      end

      # 应用预加载
      if options[:includes]
        query = query.includes(options[:includes])
      end

      query
    end

    # 数据库连接池优化
    # @param operation [Proc] 数据库操作
    # @return [Object] 操作结果
    def with_connection_pooling(&operation)
      # 在生产环境中使用连接池
      if Rails.env.production?
        ActiveRecord::Base.connection_pool.with_connection(&operation)
      else
        operation.call
      end
    end

    # 响应压缩
    # @param data [Hash, String] 要压缩的数据
    # @param request [ActionDispatch::Request] 请求对象
    # @return [String] 压缩后的数据
    def compress_response_if_needed(data, request = nil)
      return data unless should_compress?(data, request)

      # 压缩数据
      compressed_data = compress_data(data)

      # 返回压缩标记和数据
      {
        compressed: true,
        data: compressed_data,
        original_size: data.to_s.length,
        compressed_size: compressed_data.length
      }
    end

    # 缓存热数据
    # @param cache_key [String] 缓存键
    # @param ttl [Integer] 缓存时间（秒）
    # @param options [Hash] 缓存选项
    # @yield 要缓存的操作
    # @return [Object] 缓存的结果
    def cache_hot_data(cache_key, ttl: 5.minutes, options = {})
      # 检查是否应该使用缓存
      return yield unless should_use_cache?(cache_key, options)

      # 生成完整的缓存键
      full_cache_key = generate_cache_key(cache_key, options)

      # 尝试从缓存获取数据
      cached_data = Rails.cache.read(full_cache_key)
      return cached_data if cached_data

      # 缓存未命中，执行操作
      data = yield

      # 写入缓存
      Rails.cache.write(full_cache_key, data, expires_in: ttl)

      data
    end

    # 智能缓存预热
    # @param cache_keys [Array] 需要预热的缓存键数组
    def warm_up_cache(cache_keys)
      return if cache_keys.empty?

      Rails.logger.info "开始缓存预热，共 #{cache_keys.length} 个缓存键"

      cache_keys.each_with_index do |cache_key, index|
        begin
          # 并行预热缓存
          Thread.new do
            case cache_key
            when 'system_overview'
              CacheService.cache_system_overview
            when 'leaderboard_flowers_week'
              CacheService.cache_leaderboard(:flowers, :week)
            when 'leaderboard_check_ins_week'
              CacheService.cache_leaderboard(:check_ins, :week)
            when 'app_config'
              CacheService.cache_app_config
            end
          end

          # 每100个缓存键输出一次进度
          if (index + 1) % 100 == 0
            Rails.logger.info "缓存预热进度: #{index + 1}/#{cache_keys.length}"
          end
        rescue => e
          Rails.logger.error "缓存预热失败: #{cache_key} - #{e.message}"
        end
      end

      Rails.logger.info "缓存预热完成"
    end

    # 响应时间统计
    # @param period [Symbol] 统计周期 (:hour, :day, :week)
    # @return [Hash] 统计数据
    def response_time_statistics(period = :hour)
      cache_key = "response_time_stats:#{period}"

      Rails.cache.fetch(cache_key, expires_in: 1.hour) do
        # 这里可以从监控系统获取响应时间统计
        generate_mock_statistics(period)
      end
    end

    # 慢查询检测
    # @param threshold [Float] 慢查询阈值（秒）
    # @param period [Integer] 统计周期（分钟）
    # @return [Array] 慢查询列表
    def detect_slow_queries(threshold = 2.0, period = 60)
      cache_key = "slow_queries:#{threshold}:#{period}"

      Rails.cache.fetch(cache_key, expires_in: period.minutes) do
        # 这里可以从数据库日志中获取慢查询
        []
      end
    end

    # 优化建议生成
    # @param performance_data [Hash] 性能数据
    # @return [Array] 优化建议列表
    def generate_optimization_suggestions(performance_data)
      suggestions = []

      # 分析响应时间
      if performance_data[:avg_response_time] > 1.0
        suggestions << {
          type: :response_time,
          priority: :high,
          message: "平均响应时间较长(#{performance_data[:avg_response_time].round(2)}s)，建议优化数据库查询和增加缓存"
        }
      end

      # 分析缓存命中率
      if performance_data[:cache_hit_rate] && performance_data[:cache_hit_rate] < 0.8
        suggestions << {
          type: :cache,
          priority: :medium,
          message: "缓存命中率较低(#{(performance_data[:cache_hit_rate] * 100).round(1)}%)，建议优化缓存策略"
        }
      end

      # 分析数据库查询数量
      if performance_data[:queries_per_request] && performance_data[:queries_per_request] > 10
        suggestions << {
          type: :database,
          priority: :medium,
          message: "平均请求数据库查询过多(#{performance_data[:queries_per_request]})，建议使用预加载和批量查询"
        }
      end

      suggestions
    end

    private

    # 检查是否应该压缩响应
    def should_compress?(data, request = nil)
      return false if data.blank?

      # 检查数据大小
      data_size = data.to_s.length
      return false if data_size < 1024 # 小于1KB不压缩

      # 检查客户端是否支持压缩
      if request
        accept_encoding = request.headers['Accept-Encoding'] || ''
        return false unless accept_encoding.include?('gzip')
      end

      true
    end

    # 压缩数据
    def compress_data(data)
      require 'zlib'
      require 'base64'

      json_data = data.to_json
      compressed = Zlib::Deflate.deflate(json_data)
      Base64.strict_encode64(compressed)
    end

    # 检查是否有合适的排序索引
    def has_index_for_order?(model_class, order_clause)
      # 这里可以查询数据库schema来检查索引
      # 简化实现：假设常用的排序字段都有索引
      common_indexed_fields = %w[id created_at updated_at status title name]
      field = order_clause.split.first.to_s.gsub(/\s+(ASC|DESC)$/i, '')
      common_indexed_fields.include?(field)
    end

    # 检查是否应该使用缓存
    def should_use_cache?(cache_key, options = {})
      return false if options[:force_no_cache]

      # 开发环境可以选择性使用缓存
      return false if Rails.env.development? && !options[:force_cache]

      true
    end

    # 生成缓存键
    def generate_cache_key(base_key, options = {})
      key_parts = [base_key]

      # 添加用户相关的键
      if options[:user_id]
        key_parts << "user:#{options[:user_id]}"
      end

      # 添加角色相关的键
      if options[:user_role]
        key_parts << "role:#{options[:user_role]}"
      end

      # 添加时间相关的键
      if options[:time_based]
        key_parts << "time:#{Time.current.to_i / options[:time_based]}"
      end

      key_parts.join(':')
    end

    # 记录性能指标
    def record_performance_metrics(operation_name, response_time, options, success, error = nil)
      metrics = {
        operation: operation_name,
        response_time: response_time.round(3),
        success: success,
        timestamp: Time.current,
        request_id: RequestStore.store[:request_id]
      }

      # 添加额外的指标
      if options[:user_id]
        metrics[:user_id] = options[:user_id]
      end

      if options[:cache_hit]
        metrics[:cache_hit] = options[:cache_hit]
      end

      if options[:query_count]
        metrics[:query_count] = options[:query_count]
      end

      # 错误信息
      if error
        metrics[:error] = error.message
      end

      # 发送到监控系统
      send_metrics_to_monitoring_service(metrics)
    end

    # 发送指标到监控服务
    def send_metrics_to_monitoring_service(metrics)
      # 这里可以集成StatsD、Prometheus、DataDog等监控服务
      # 示例：
      if defined?(StatsD)
        StatsD.timing("api.#{metrics[:operation]}.response_time", metrics[:response_time] * 1000)
        StatsD.increment("api.#{metrics[:operation]}.#{metrics[:success] ? 'success' : 'error'}")
      end
    end

    # 生成模拟统计数据
    def generate_mock_statistics(period)
      case period
      when :hour
        {
          avg_response_time: 0.8,
          cache_hit_rate: 0.85,
          queries_per_request: 5.2,
          requests_per_minute: 120,
          error_rate: 0.02
        }
      when :day
        {
          avg_response_time: 0.9,
          cache_hit_rate: 0.82,
          queries_per_request: 6.1,
          requests_per_minute: 100,
          error_rate: 0.03
        }
      when :week
        {
          avg_response_time: 1.1,
          cache_hit_rate: 0.78,
          queries_per_request: 7.5,
          requests_per_minute: 80,
          error_rate: 0.04
        }
      else
        {
          avg_response_time: 1.0,
          cache_hit_rate: 0.80,
          queries_per_request: 6.0,
          requests_per_minute: 100,
          error_rate: 0.03
        }
      end
    end
  end
end