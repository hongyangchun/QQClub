# frozen_string_literal: true

# GlobalErrorHandlerService - 全局错误处理服务
# 提供统一的错误处理、日志记录和用户友好的错误响应
class GlobalErrorHandlerService < ApplicationService

  attr_reader :exception, :context, :user, :request_id

  def initialize(exception:, context: {}, user: nil, request_id: nil)
    super()
    @exception = exception
    @context = context
    @user = user
    @request_id = request_id || SecureRandom.uuid
  end

  def call
    handle_errors do
      log_error
      determine_error_response
    end
    self
  end

  # 类方法：处理控制器异常
  def self.handle_controller_exception(exception, controller, action = nil)
    user = controller.respond_to?(:current_user) ? controller.current_user : nil
    request_id = controller.request&.request_id

    new(
      exception: exception,
      context: {
        controller: controller.class.name,
        action: action,
        method: controller.request&.request_method,
        path: controller.request&.path,
        ip: controller.request&.remote_ip,
        user_agent: controller.request&.user_agent
      },
      user: user,
      request_id: request_id
    ).call
  end

  # 类方法：处理服务异常
  def self.handle_service_exception(exception, service_name, action = nil)
    new(
      exception: exception,
      context: {
        service: service_name,
        action: action
      },
      user: nil,
      request_id: SecureRandom.uuid
    ).call
  end

  def error_response
    @error_response
  end

  def error_code
    @error_code ||= determine_error_code
  end

  def error_message
    @error_message ||= determine_error_message
  end

  def should_retry?
    @should_retry ||= determine_retry_eligibility
  end

  def severity
    @severity ||= determine_severity
  end

  private

  def log_error
    return unless should_log_error?

    # 基本错误信息 - 修复参数数量问题
    log_details = {
      request_id: request_id,
      user_id: user&.id,
      user_role: user&.role_as_string,
      context: context,
      exception_class: exception.class.name,
      exception_message: exception.message,
      backtrace: exception.backtrace&.first(10)
    }

    Rails.logger.error("[#{severity.upcase}] #{exception.class.name}: #{exception.message} - #{log_details.to_json}")

    # 详细错误信息（仅在开发环境）
    if Rails.env.development?
      backtrace_info = exception.backtrace&.join("\n") || "无堆栈信息"
      Rails.logger.debug("完整错误堆栈: #{backtrace_info}")
    end

    # 发送错误通知（生产环境）
    send_error_notification if should_send_notification?
  end

  def determine_error_response
    case exception
    when ActionController::ParameterMissing, ActionController::BadRequest
      build_validation_error_response
    when ActiveRecord::RecordNotFound
      build_not_found_error_response
    when ActiveRecord::RecordInvalid
      build_validation_error_response
    when ActionDispatch::InvalidParameterError
      build_parameter_error_response
    when JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature
      build_authentication_error_response
    when Timeout::Error, ActiveRecord::StatementInvalid
      build_system_error_response
    else
      build_general_error_response
    end
  end

  def determine_error_code
    case exception
    when ActionController::ParameterMissing
      'MISSING_PARAMETER'
    when ActionController::BadRequest
      'INVALID_REQUEST'
    when ActiveRecord::RecordNotFound
      'RESOURCE_NOT_FOUND'
    when ActiveRecord::RecordInvalid
      'VALIDATION_ERROR'
    when ActionDispatch::InvalidParameterError
      'INVALID_PARAMETER'
    when JWT::DecodeError, JWT::VerificationError
      'INVALID_TOKEN'
    when JWT::ExpiredSignature
      'TOKEN_EXPIRED'
    when Timeout::Error
      'TIMEOUT_ERROR'
    when ActiveRecord::StatementInvalid
      'DATABASE_ERROR'
    else
      'INTERNAL_ERROR'
    end
  end

  def determine_error_message
    case exception
    when ActionController::ParameterMissing
      "缺少必需的参数: #{exception.param}"
    when ActionController::BadRequest
      "请求格式错误"
    when ActiveRecord::RecordNotFound
      "请求的资源不存在"
    when ActiveRecord::RecordInvalid
      "数据验证失败: #{format_validation_errors}"
    when ActionDispatch::InvalidParameterError
      "参数格式错误: #{exception.message}"
    when JWT::DecodeError, JWT::VerificationError
      "认证令牌无效"
    when JWT::ExpiredSignature
      "认证令牌已过期"
    when Timeout::Error
      "请求超时，请稍后重试"
    when ActiveRecord::StatementInvalid
      "数据库操作失败"
    else
      "系统繁忙，请稍后重试"
    end
  end

  def determine_retry_eligibility
    # 可以重试的错误类型
    retryable_errors = [
      Timeout::Error,
      ActiveRecord::StatementInvalid,
      Net::TimeoutError,
      Net::ReadTimeout,
      Net::OpenTimeout
    ]

    retryable_errors.include?(exception.class) && !should_fail_fast?
  end

  def determine_severity
    case exception
    when ActionController::ParameterMissing, ActiveRecord::RecordInvalid
      :low
    when ActionDispatch::InvalidParameterError, JWT::DecodeError
      :medium
    when Timeout::Error, ActiveRecord::StatementInvalid
      :high
    else
      :critical
    end
  end

  def build_validation_error_response
    errors = extract_validation_errors

    {
      error: error_message,
      error_code: error_code,
      error_type: 'validation_error',
      errors: errors,
      request_id: request_id,
      timestamp: Time.current.iso8601,
      details: {
        context: context,
        fix_suggestions: generate_fix_suggestions
      }
    }
  end

  def build_not_found_error_response
    {
      error: error_message,
      error_code: error_code,
      error_type: 'not_found',
      request_id: request_id,
      timestamp: Time.current.iso8601,
      details: {
        context: context,
        suggestions: [
          '请检查资源ID是否正确',
          '确认资源是否存在且未被删除'
        ]
      }
    }
  end

  def build_parameter_error_response
    {
      error: error_message,
      error_code: error_code,
      error_type: 'parameter_error',
      request_id: request_id,
      timestamp: Time.current.iso8601,
      details: {
        context: context,
        parameter_info: extract_parameter_info,
        suggestions: [
          '请检查请求参数格式',
          '参考API文档确认参数要求'
        ]
      }
    }
  end

  def build_authentication_error_response
    {
      error: error_message,
      error_code: error_code,
      error_type: 'authentication_error',
      request_id: request_id,
      timestamp: Time.current.iso8601,
      details: {
        context: context,
        auth_info: extract_auth_info,
        suggestions: [
          '请重新登录获取有效令牌',
          '检查令牌是否完整且未过期'
        ]
      }
    }
  end

  def build_system_error_response
    {
      error: error_message,
      error_code: error_code,
      error_type: 'system_error',
      request_id: request_id,
      timestamp: Time.current.iso8601,
      details: {
        context: context,
        severity: severity,
        suggestions: [
          '请稍后重试',
          '如问题持续存在，请联系技术支持'
        ]
      }
    }
  end

  def build_general_error_response
    {
      error: error_message,
      error_code: error_code,
      error_type: 'general_error',
      request_id: request_id,
      timestamp: Time.current.iso8601,
      details: {
        context: context,
        exception_class: exception.class.name,
        severity: severity,
        suggestions: [
          '请检查请求格式并重试',
          '如问题持续存在，请联系技术支持'
        ]
      }
    }
  end

  def extract_validation_errors
    if exception.is_a?(ActiveRecord::RecordInvalid)
      exception.record.errors.full_messages
    elsif exception.is_a?(ActionController::ParameterMissing)
      [exception.message]
    elsif exception.respond_to?(:errors)
      exception.errors.full_messages
    else
      [exception.message]
    end
  end

  def extract_parameter_info
    return {} unless context

    {
      method: context[:method],
      path: context[:path],
      controller: context[:controller],
      action: context[:action]
    }
  end

  def extract_auth_info
    return {} unless user

    {
      user_id: user.id,
      user_role: user.role_as_string,
      user_nickname: user.nickname
    }
  end

  def generate_fix_suggestions
    suggestions = []

    case exception
    when ActiveRecord::RecordInvalid
      suggestions << "请检查必填字段是否完整"
      suggestions << "确认数据格式是否正确"
    when ActionController::ParameterMissing
      suggestions << "请添加缺少的必需参数"
    when ActionController::BadRequest
      suggestions << "请检查请求格式和参数"
    end

    suggestions
  end

  def should_log_error?
    # 不记录的错误类型（避免日志噪音）
    non_loggable_errors = [
      'MISSING_PARAMETER',
      'INVALID_REQUEST'
    ]

    return false if non_loggable_errors.include?(error_code)
    true
  end

  def should_send_notification?
    return false unless Rails.env.production?
    return false unless severity == :critical
    return false if exception.is_a?(ActiveRecord::RecordNotFound)
    return false if exception.is_a?(ActionController::ParameterMissing)

    true
  end

  def send_error_notification
    # 这里可以集成通知系统，如Slack、邮件等
    # 示例实现：
    begin
      ErrorNotificationService.notify(
        error: exception,
        context: context,
        user: user,
        request_id: request_id
      )
    rescue => e
      Rails.logger.error "发送错误通知失败: #{e.message}"
    end
  end

  def should_fail_fast?
    # 需要快速失败的错误类型
    fail_fast_errors = [
      'MISSING_AUTH_HEADER',
      'INVALID_TOKEN_FORMAT',
      'TOKEN_EXPIRED'
    ]

    fail_fast_errors.include?(error_code)
  end
end