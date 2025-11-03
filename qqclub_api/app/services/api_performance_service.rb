# frozen_string_literal: true

# API性能优化服务
# 提供API请求限流、分页优化、批量操作等功能
class ApiPerformanceService
  class << self
    # API请求限流
    # @param identifier [String] 请求标识符（用户ID、IP地址等）
    # @param limit [Integer] 请求限制数量
    # @param period [Integer] 时间周期（秒）
    # @param cache_key_prefix [String] 缓存键前缀
    # @return [Hash] 限流结果
    def rate_limit(identifier, limit: 100, period: 60, cache_key_prefix: 'rate_limit')
      cache_key = "#{cache_key_prefix}:#{identifier}:#{Time.current.to_i / period}"
      current_count = Rails.cache.read(cache_key) || 0

      if current_count >= limit
        {
          allowed: false,
          remaining: 0,
          reset_time: (Time.current.to_i / period + 1) * period,
          retry_after: period - (Time.current.to_i % period)
        }
      else
        # 增加计数
        Rails.cache.write(cache_key, current_count + 1, expires_in: period)

        {
          allowed: true,
          remaining: limit - current_count - 1,
          reset_time: (Time.current.to_i / period + 1) * period,
          current_count: current_count + 1
        }
      end
    end

    # 智能API响应格式化
    # @param success [Boolean] 请求是否成功
    # @param data [Object] 响应数据
    # @param message [String] 响应消息
    # @param meta [Hash] 元数据
    # @param status_code [Integer] HTTP状态码
    # @return [Hash] 格式化的API响应
    def format_api_response(success: true, data: nil, message: nil, meta: {}, status_code: 200)
      response = {
        success: success,
        message: message,
        data: data,
        meta: meta
      }

      # 添加时间戳
      response[:timestamp] = Time.current.iso8601

      # 添加请求ID（如果存在）
      if RequestStore.store[:request_id]
        response[:request_id] = RequestStore.store[:request_id]
      end

      response
    end

    # 优化的分页响应
    # @param pagination_result [Hash] 分页结果
    # @param additional_meta [Hash] 额外的元数据
    # @return [Hash] 格式化的分页响应
    def format_paginated_response(pagination_result, additional_meta = {})
      meta = pagination_result[:pagination] || {}
      meta.merge!(additional_meta)

      format_api_response(
        success: true,
        data: pagination_result[:records],
        meta: meta
      )
    end

    # 批量操作支持
    # @param records [Array] 记录数组
    # @param batch_size [Integer] 批次大小
    # @param options [Hash] 操作选项
    # @yield [Array] 每批记录
    # @return [Array] 所有操作结果
    def batch_process(records, batch_size: 50, options = {})
      return [] if records.empty?

      results = []
      total_batches = (records.length.to_f / batch_size).ceil
      current_batch = 1

      records.each_slice(batch_size) do |batch|
        begin
          batch_result = yield(batch) if block_given?

          if batch_result.is_a?(Array)
            results.concat(batch_result)
          else
            results << batch_result
          end

          # 批次操作日志
          Rails.logger.info "批量操作进度: #{current_batch}/#{total_batches} 批次完成" if options[:log_progress]

        rescue => e
          Rails.logger.error "批量操作失败 (批次 #{current_batch}): #{e.message}"

          if options[:continue_on_error]
            results << { error: e.message, batch: current_batch }
          else
            raise e
          end
        end

        current_batch += 1
      end

      results
    end

    # API字段选择器
    # @param records [Array] 记录数组
    # @param fields [Array] 需要返回的字段
    # @param options [Hash] 选项
    # @return [Array] 选择字段后的记录
    def select_fields(records, fields, options = {})
      return records if fields.blank? || records.empty?

      records.map do |record|
        if record.respond_to?(:as_json_for_api)
          # 如果记录支持as_json_for_api方法
          record.as_json_for_api(options.slice(:includes))
        else
          record.as_json
        end.slice(*fields.map(&:to_s))
      end
    end

    # 数据压缩（对大型响应进行压缩）
    # @param data [Hash] 要压缩的数据
    # @param threshold [Integer] 压缩阈值（字符数）
    # @return [Hash] 压缩后的数据
    def compress_if_needed(data, threshold: 10240) # 10KB
      return data unless should_compress?(data, threshold)

      compressed_data = {
        compressed: true,
        data: compress_data(data),
        original_size: data.to_s.length,
        compressed_size: compress_data(data).length
      }
    end

    # API缓存装饰器
    # @param cache_key [String] 缓存键
    # @param ttl [Integer] 缓存时间（秒）
    # @param options [Hash] 缓存选项
    # @yield 要缓存的操作
    # @return [Object] 缓存的结果
    def cache_api_response(cache_key, ttl: 5.minutes, options = {})
      # 如果用户未登录，不缓存
      return yield unless options[:skip_auth_check] || RequestStore.store[:current_user]

      full_cache_key = "api_response:#{cache_key}:#{RequestStore.store[:current_user]&.id}:#{RequestStore.store[:user_role]}"

      Rails.cache.fetch(full_cache_key, expires_in: ttl, race_condition_ttl: 30.seconds) do
        yield
      end
    end

    # API性能监控
    # @param endpoint [String] API端点
    # @param method [String] HTTP方法
    # @param options [Hash] 监控选项
    # @yield 要监控的操作
    # @return [Object] 操作结果
    def monitor_performance(endpoint, method: 'GET', options = {})
      start_time = Time.current

      begin
        result = yield

        execution_time = Time.current - start_time
        log_performance_metrics(endpoint, method, execution_time, options, true)

        result
      rescue => e
        execution_time = Time.current - start_time
        log_performance_metrics(endpoint, method, execution_time, options, false, e)

        raise e
      end
    end

    # 请求参数验证和清理
    # @param params [Hash] 请求参数
    # @param allowed_params [Array] 允许的参数列表
    # @param options [Hash] 验证选项
    # @return [Hash] 清理后的参数
    def sanitize_params(params, allowed_params, options = {})
      return {} if params.blank?

      # 只保留允许的参数
      sanitized = params.slice(*allowed_params)

      # 类型转换
      sanitized = convert_param_types(sanitized, options[:type_conversions] || {})

      # 验证必填参数
      if options[:required]&.any?
        missing_params = options[:required] - sanitized.keys
        if missing_params.any?
          raise ArgumentError, "缺少必填参数: #{missing_params.join(', ')}"
        end
      end

      # 参数值验证
      if options[:validations]
        validate_param_values(sanitized, options[:validations])
      end

      sanitized
    end

    # 响应时间优化：异步处理非关键操作
    # @param operation [Symbol] 操作类型
    # @param data [Object] 操作数据
    # @param options [Hash] 操作选项
    def async_process(operation, data, options = {})
      # 使用Rails的Active Job进行异步处理
      case operation
      when :send_notification
        NotificationJob.perform_later(data, options)
      when :update_statistics
        StatisticsJob.perform_later(data, options)
      when :send_email
        EmailJob.perform_later(data, options)
      when :generate_report
        ReportJob.perform_later(data, options)
      else
        Rails.logger.warn "未知的异步操作类型: #{operation}"
      end
    end

    # 响应压缩中间件支持
    # @param response_body [String] 响应体
    # @param request_headers [Hash] 请求头
    # @return [String] 压缩后的响应体
    def compress_response(response_body, request_headers = {})
      # 检查客户端是否支持压缩
      accept_encoding = request_headers['Accept-Encoding'] || ''
      return response_body unless accept_encoding.include?('gzip')

      # 压缩响应
      require 'zlib'
      compressed = Zlib::Deflate.deflate(response_body)

      # 添加压缩标记
      response_body
    end

    # API版本控制支持
    # @param request [ActionDispatch::Request] 请求对象
    # @param available_versions [Array] 可用的API版本
    # @return [String] 选择的API版本
    def determine_api_version(request, available_versions = ['v1'])
      # 从URL路径获取版本
      version_from_path = request.path.split('/')[1]
      return version_from_path if available_versions.include?(version_from_path)

      # 从请求头获取版本
      version_from_header = request.headers['API-Version']
      return version_from_header if available_versions.include?(version_from_header)

      # 返回默认版本
      available_versions.first
    end

    # 响应格式协商
    # @param request [ActionDispatch::Request] 请求对象
    # @param data [Object] 响应数据
    # @param default_format [Symbol] 默认格式
    # @return [String] 格式化后的响应
    def negotiate_response_format(request, data, default_format = :json)
      accept_header = request.headers['Accept'] || 'application/json'

      case accept_header
      when /json/
        data.to_json
      when /xml/
        data.respond_to?(:to_xml) ? data.to_xml : data.to_json
      when /text/
        data.to_s
      else
        case default_format
        when :json
          data.to_json
        when :xml
          data.respond_to?(:to_xml) ? data.to_xml : data.to_json
        else
          data.to_s
        end
      end
    end

    private

    # 判断是否需要压缩
    def should_compress?(data, threshold)
      data.to_s.length > threshold
    end

    # 压缩数据
    def compress_data(data)
      require 'zlib'
      Base64.strict_encode64(Zlib::Deflate.deflate(data.to_json))
    end

    # 记录性能指标
    def log_performance_metrics(endpoint, method, execution_time, options, success, error = nil)
      metrics = {
        endpoint: endpoint,
        method: method,
        execution_time: execution_time.round(3),
        success: success,
        timestamp: Time.current.iso8601,
        user_id: RequestStore.store[:current_user]&.id,
        user_role: RequestStore.store[:user_role]
      }

      if error
        metrics[:error] = {
          message: error.message,
          class: error.class.name
        }
      end

      # 记录到日志
      if success && execution_time > 1.0
        Rails.logger.warn "慢查询警告: #{metrics}"
      elsif !success
        Rails.logger.error "API错误: #{metrics}"
      end

      # 发送到监控系统（如果配置了）
      if defined?(StatsD)
        StatsD.timing("api.#{endpoint.gsub('/', '_')}.#{method.downcase}", execution_time * 1000)
        StatsD.increment("api.#{endpoint.gsub('/', '_')}.#{method.downcase}.#{success ? 'success' : 'error'}")
      end
    end

    # 参数类型转换
    def convert_param_types(params, type_conversions)
      converted = params.dup

      type_conversions.each do |key, type|
        next unless converted.key?(key)

        case type
        when :integer
          converted[key] = converted[key].to_i
        when :float
          converted[key] = converted[key].to_f
        when :boolean
          converted[key] = %w[true yes 1 t].include?(converted[key].to_s.downcase)
        when :date
          converted[key] = Date.parse(converted[key]) rescue nil
        when :datetime
          converted[key] = DateTime.parse(converted[key]) rescue nil
        end
      end

      converted
    end

    # 参数值验证
    def validate_param_values(params, validations)
      validations.each do |key, rules|
        next unless params.key?(key)

        value = params[key]

        # 必填验证
        if rules[:required] && value.blank?
          raise ArgumentError, "参数 #{key} 是必填的"
        end

        # 范围验证
        if rules[:range] && value.present?
          min_val, max_val = rules[:range]
          if min_val && value < min_val
            raise ArgumentError, "参数 #{key} 不能小于 #{min_val}"
          end
          if max_val && value > max_val
            raise ArgumentError, "参数 #{key} 不能大于 #{max_val}"
          end
        end

        # 长度验证
        if rules[:length] && value.present?
          min_len, max_len = rules[:length]
          if min_len && value.to_s.length < min_len
            raise ArgumentError, "参数 #{key} 长度不能小于 #{min_len}"
          end
          if max_len && value.to_s.length > max_len
            raise ArgumentError, "参数 #{key} 长度不能大于 #{max_len}"
          end
        end

        # 正则表达式验证
        if rules[:format] && value.present?
          regex = rules[:format].is_a?(Regexp) ? rules[:format] : Regexp.new(rules[:format])
          unless value.to_s.match?(regex)
            raise ArgumentError, "参数 #{key} 格式不正确"
          end
        end

        # 枚举值验证
        if rules[:in] && value.present?
          unless rules[:in].include?(value)
            raise ArgumentError, "参数 #{key} 必须是以下值之一: #{rules[:in].join(', ')}"
          end
        end
      end
    end
  end
end