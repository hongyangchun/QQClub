# frozen_string_literal: true

# 错误处理服务
# 提供统一的错误处理、日志记录和用户友好的错误消息
class ErrorHandlingService
  class << self
    # 处理API错误并返回标准化响应
    # @param error [Exception] 错误对象
    # @param context [Hash] 错误上下文信息
    # @return [Hash] 标准化的错误响应
    def handle_api_error(error, context = {})
      error_info = classify_error(error)

      # 记录错误日志
      log_error(error, context, error_info)

      # 清除相关的缓存
      clear_related_cache(context) if error_info[:clear_cache]

      # 发送错误通知（如果是严重错误）
      notify_error(error, context, error_info) if error_info[:notify]

      # 返回用户友好的错误响应
      format_error_response(error_info, error, context)
    end

    # 验证错误处理
    # @param errors [ActiveModel::Errors] 验证错误对象
    # @param context [Hash] 上下文信息
    # @return [Hash] 标准化的验证错误响应
    def handle_validation_errors(errors, context = {})
      error_details = errors.details.transform_values do |details|
        details.map { |detail| detail[:error].to_s.humanize }
      end

      response = {
        success: false,
        error_type: 'validation_error',
        message: '请求参数验证失败',
        errors: error_details,
        timestamp: Time.current.iso8601
      }

      # 添加请求ID
      if RequestStore.store[:request_id]
        response[:request_id] = RequestStore.store[:request_id]
      end

      # 记录验证错误日志
      Rails.logger.warn "验证错误: #{context[:action]} - #{error_details}"

      response
    end

    # 资源未找到错误处理
    # @param resource_type [String] 资源类型
    # @param resource_id [String, Integer] 资源ID
    # @param context [Hash] 上下文信息
    # @return [Hash] 标准化的未找到响应
    def handle_not_found_error(resource_type, resource_id = nil, context = {})
      message = if resource_id
                  "#{resource_type.humanize} (ID: #{resource_id}) 不存在"
                else
                  "#{resource_type.humanize} 不存在"
                end

      response = {
        success: false,
        error_type: 'not_found',
        message: message,
        resource_type: resource_type,
        resource_id: resource_id,
        timestamp: Time.current.iso8601
      }

      # 添加请求ID
      if RequestStore.store[:request_id]
        response[:request_id] = RequestStore.store[:request_id]
      end

      # 记录404日志
      Rails.logger.info "404错误: #{context[:action]} - #{message}"

      response
    end

    # 权限错误处理
    # @param action [String] 请求的操作
    # @param resource [String] 资源信息
    # @param context [Hash] 上下文信息
    # @return [Hash] 标准化的权限错误响应
    def handle_authorization_error(action, resource = nil, context = {})
      message = if resource
                  "您没有权限执行此操作: #{action} #{resource}"
                else
                  "您没有权限执行此操作: #{action}"
                end

      response = {
        success: false,
        error_type: 'authorization_error',
        message: message,
        required_permission: action,
        timestamp: Time.current.iso8601
      }

      # 添加用户信息
      if context[:user]
        response[:user_info] = {
          id: context[:user].id,
          role: context[:user].role_as_string
        }
      end

      # 添加请求ID
      if RequestStore.store[:request_id]
        response[:request_id] = RequestStore.store[:request_id]
      end

      # 记录权限错误日志
      Rails.logger.warn "权限错误: #{context[:user]&.id} - #{message}"

      response
    end

    # 业务逻辑错误处理
    # @param message [String] 错误消息
    # @param error_code [String] 错误代码
    # @param context [Hash] 上下文信息
    # @return [Hash] 标准化的业务错误响应
    def handle_business_error(message, error_code = nil, context = {})
      response = {
        success: false,
        error_type: 'business_error',
        message: message,
        error_code: error_code,
        timestamp: Time.current.iso8601
      }

      # 添加请求ID
      if RequestStore.store[:request_id]
        response[:request_id] = RequestStore.store[:request_id]
      end

      # 记录业务错误日志
      Rails.logger.info "业务错误: #{context[:action]} - #{message}"

      response
    end

    # 服务不可用错误处理
    # @param service_name [String] 服务名称
    # @param context [Hash] 上下文信息
    # @return [Hash] 标准化的服务不可用响应
    def handle_service_unavailable_error(service_name, context = {})
      message = "#{service_name} 服务暂时不可用，请稍后再试"

      response = {
        success: false,
        error_type: 'service_unavailable',
        message: message,
        service_name: service_name,
        retry_after: 30, # 建议重试时间（秒）
        timestamp: Time.current.iso8601
      }

      # 添加请求ID
      if RequestStore.store[:request_id]
        response[:request_id] = RequestStore.store[:request_id]
      end

      # 记录服务不可用日志
      Rails.logger.error "服务不可用: #{service_name} - #{context[:action]}"

      response
    end

    # 限流错误处理
    # @param limit_info [Hash] 限流信息
    # @param context [Hash] 上下文信息
    # @return [Hash] 标准化的限流错误响应
    def handle_rate_limit_error(limit_info, context = {})
      response = {
        success: false,
        error_type: 'rate_limit_exceeded',
        message: '请求过于频繁，请稍后再试',
        limit_info: limit_info,
        timestamp: Time.current.iso8601
      }

      # 添加请求ID
      if RequestStore.store[:request_id]
        response[:request_id] = RequestStore.store[:request_id]
      end

      # 记录限流日志
      Rails.logger.warn "限流错误: #{context[:action]} - #{limit_info}"

      response
    end

    # 创建用户友好的错误消息
    # @param error_class [Class] 错误类
    # @param error_message [String] 原始错误消息
    # @param context [Hash] 上下文信息
    # @return [String] 用户友好的错误消息
    def create_user_friendly_message(error_class, error_message, context = {})
      case error_class.name
      when 'ActiveRecord::RecordNotFound'
        case context[:resource_type]
        when 'User'
          '用户不存在'
        when 'ReadingEvent'
          '活动不存在'
        when 'CheckIn'
          '打卡记录不存在'
        when 'Flower'
          '小红花不存在'
        else
          '记录不存在'
        end
      when 'ActiveRecord::RecordInvalid'
        '数据验证失败，请检查输入信息'
      when 'ActiveRecord::RecordNotSaved'
        '保存失败，请检查网络连接后重试'
      when 'ArgumentError'
        '请求参数不正确'
      when 'JWT::DecodeError'
        '登录信息无效，请重新登录'
      when 'NoMethodError'
        '功能暂时不可用'
      when 'StandardError'
        if error_message.include?('数据库') || error_message.include?('database')
          '数据服务暂时不可用，请稍后再试'
        elsif error_message.include?('网络') || error_message.include?('network')
          '网络连接异常，请检查网络后重试'
        elsif error_message.include?('超时') || error_message.include?('timeout')
          '请求超时，请稍后再试'
        else
          '系统暂时异常，请稍后再试'
        end
      else
        '系统暂时异常，请稍后再试'
      end
    end

    # 错误分类
    # @param error [Exception] 错误对象
    # @return [Hash] 错误分类信息
    def classify_error(error)
      base_info = {
        class_name: error.class.name,
        message: error.message,
        backtrace: error.backtrace&.first(5)
      }

      case error
      when ActiveRecord::RecordNotFound
        base_info.merge(
          severity: :low,
          user_friendly: true,
          http_status: 404,
          clear_cache: false,
          notify: false
        )
      when ActiveRecord::RecordInvalid, ArgumentError
        base_info.merge(
          severity: :low,
          user_friendly: true,
          http_status: 400,
          clear_cache: false,
          notify: false
        )
      when JWT::DecodeError, ActionController::InvalidAuthenticityToken
        base_info.merge(
          severity: :medium,
          user_friendly: true,
          http_status: 401,
          clear_cache: false,
          notify: false
        )
      when ActiveRecord::RecordNotSaved, ActiveRecord::StatementInvalid
        base_info.merge(
          severity: :medium,
          user_friendly: true,
          http_status: 422,
          clear_cache: false,
          notify: true
        )
      when StandardError
        if error.message.include?('超时') || error.message.include?('timeout')
          base_info.merge(
            severity: :medium,
            user_friendly: true,
            http_status: 408,
            clear_cache: false,
            notify: false
          )
        elsif error.message.include?('权限') || error.message.include?('permission')
          base_info.merge(
            severity: :medium,
            user_friendly: true,
            http_status: 403,
            clear_cache: false,
            notify: false
          )
        else
          base_info.merge(
            severity: :high,
            user_friendly: false,
            http_status: 500,
            clear_cache: true,
            notify: true
          )
        end
      else
        base_info.merge(
          severity: :high,
          user_friendly: false,
          http_status: 500,
          clear_cache: true,
          notify: true
        )
      end
    end

    # 记录错误日志
    # @param error [Exception] 错误对象
    # @param context [Hash] 上下文信息
    # @param error_info [Hash] 错误分类信息
    def log_error(error, context, error_info)
      log_data = {
        error_class: error_info[:class_name],
        error_message: error_info[:message],
        severity: error_info[:severity],
        context: context,
        timestamp: Time.current,
        backtrace: error_info[:backtrace]
      }

      # 添加用户信息
      if context[:user]
        log_data[:user_id] = context[:user].id
        log_data[:user_role] = context[:user].role_as_string
      end

      # 根据严重程度选择日志级别
      case error_info[:severity]
      when :low
        Rails.logger.info "错误日志: #{log_data}"
      when :medium
        Rails.logger.warn "警告日志: #{log_data}"
      when :high
        Rails.logger.error "错误日志: #{log_data}"
      end

      # 发送到外部错误监控服务
      send_to_error_monitoring(log_data) if error_info[:notify]
    end

    # 清除相关缓存
    # @param context [Hash] 上下文信息
    def clear_related_cache(context)
      return unless context[:user]

      case context[:action]
      when 'create', 'update', 'destroy'
        CacheService.clear_user_cache(context[:user])
      end
    end

    # 发送错误通知
    # @param error [Exception] 错误对象
    # @param context [Hash] 上下文信息
    # @param error_info [Hash] 错误分类信息
    def notify_error(error, context, error_info)
      return unless Rails.env.production? # 只在生产环境发送通知

      # 这里可以集成邮件、Slack、钉钉等通知服务
      error_data = {
        error_class: error_info[:class_name],
        error_message: error_info[:message],
        context: context,
        timestamp: Time.current,
        environment: Rails.env
      }

      # 示例：发送到Slack（需要配置webhook）
      # SlackNotifier.notify_error(error_data) if defined?(SlackNotifier)
    end

    # 格式化错误响应
    # @param error_info [Hash] 错误分类信息
    # @param error [Exception] 错误对象
    # @param context [Hash] 上下文信息
    # @return [Hash] 标准化的错误响应
    def format_error_response(error_info, error, context)
      user_friendly_message = create_user_friendly_message(
        error.class,
        error_info[:message],
        context
      )

      response = {
        success: false,
        error_type: error_info[:class_name].underscore,
        message: user_friendly_message,
        timestamp: Time.current.iso8601
      }

      # 开发环境显示详细信息
      if Rails.env.development?
        response[:debug] = {
          original_error: error_info[:message],
          backtrace: error_info[:backtrace],
          context: context
        }
      end

      # 添加请求ID
      if RequestStore.store[:request_id]
        response[:request_id] = RequestStore.store[:request_id]
      end

      response
    end

    # 发送错误到外部监控服务
    # @param error_data [Hash] 错误数据
    def send_to_error_monitoring(error_data)
      # 这里可以集成Sentry、Bugsnag、Rollbar等错误监控服务
      # 示例：
      # Sentry.capture_exception(error_data[:error], extra: error_data)
    end

    # 异常处理装饰器
    # @param operation [Symbol] 操作类型
    # @param context [Hash] 上下文信息
    # @param options [Hash] 选项
    # @yield 要执行的操作
    # @return [Object] 操作结果或错误响应
    def with_error_handling(operation, context = {}, options = {})
      begin
        yield
      rescue => e
        if options[:return_response]
          handle_api_error(e, context.merge(operation: operation))
        else
          raise e
        end
      end
    end

    # 批量错误处理
    # @param operations [Array] 操作数组
    # @param context [Hash] 上下文信息
    # @return [Hash] 批量处理结果
    def handle_batch_errors(operations, context = {})
      results = {
        successful: [],
        failed: [],
        total: operations.length
      }

      operations.each_with_index do |operation, index|
        begin
          result = yield(operation) if block_given?
          results[:successful] << {
            index: index,
            operation: operation,
            result: result
          }
        rescue => e
          error_response = handle_api_error(e, context.merge(operation: operation))
          results[:failed] << {
            index: index,
            operation: operation,
            error: error_response
          }
        end
      end

      results
    end
  end
end