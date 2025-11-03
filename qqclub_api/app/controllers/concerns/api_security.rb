# frozen_string_literal: true

# ApiSecurity - API安全增强模块
# 提供API安全相关功能，包括限流、CSRF保护、请求验证等
module ApiSecurity
  extend ActiveSupport::Concern

  included do
    # 添加请求ID追踪
    before_action :set_request_id
    # 添加安全头
    before_action :set_security_headers
    # API限流检查（现在不会执行实际限流）
    before_action :check_rate_limits
    # 参数安全检查
    before_action :validate_request_security
    # 记录API访问日志
    after_action :log_api_access
  end

  private

  # 设置请求ID
  def set_request_id
    request_id = request.headers['X-Request-ID'] || SecureRandom.uuid
    response.headers['X-Request-ID'] = request_id
    @request_id = request_id
  end

  # 设置安全头
  def set_security_headers
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
    response.headers['Content-Security-Policy'] = "default-src 'self'"
    response.headers['X-API-Version'] = api_version
    response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate' if sensitive_request?
  end

  # 检查API限流
  def check_rate_limits
    # IP限流检查
    rate_limiter = ApiRateLimitingService.check_ip_rate_limit(
      request.remote_ip,
      endpoint: request.path,
      request: request
    )

    unless rate_limiter.allowed?
      render_rate_limit_error(
        limit: rate_limiter.limit,
        remaining: rate_limiter.remaining_requests,
        reset_time: rate_limiter.reset_time,
        retry_after: calculate_retry_after(rate_limiter.reset_time)
      )
      return false
    end

    # 用户限流检查（如果已认证）
    if current_user
      user_rate_limiter = ApiRateLimitingService.check_user_rate_limit(
        current_user,
        endpoint: request.path,
        request: request
      )

      unless user_rate_limiter.allowed?
        render_rate_limit_error(
          limit: user_rate_limiter.limit,
          remaining: user_rate_limiter.remaining_requests,
          reset_time: user_rate_limiter.reset_time,
          retry_after: calculate_retry_after(user_rate_limiter.reset_time),
          scope: 'user'
        )
        return false
      end
    end

    # 全局限流检查
    global_rate_limiter = ApiRateLimitingService.check_global_rate_limit(
      endpoint: request.path,
      request: request
    )

    unless global_rate_limiter.allowed?
      render_rate_limit_error(
        limit: global_rate_limiter.limit,
        remaining: global_rate_limiter.remaining_requests,
        reset_time: global_rate_limiter.reset_time,
        retry_after: calculate_retry_after(global_rate_limiter.reset_time),
        scope: 'global'
      )
      return false
    end

    true
  end

  # 请求安全验证
  def validate_request_security
    # 检查User-Agent
    validate_user_agent

    # 检查请求大小
    validate_request_size

    # 检查可疑参数
    validate_suspicious_params

    # 检查请求频率模式
    validate_request_pattern
  end

  # 验证User-Agent
  def validate_user_agent
    user_agent = request.user_agent

    if user_agent.blank?
      render_error_response(
        error: '缺少User-Agent头',
        error_code: 'MISSING_USER_AGENT',
        error_type: 'security_error',
        status: :bad_request
      )
      return false
    end

    # 检查可疑的User-Agent模式
    suspicious_patterns = [
      /bot/i, /crawler/i, /spider/i,
      /scanner/i, /wget/i, /curl/i,
      /python/i, /java/i, /go-http/i
    ]

    if suspicious_patterns.any? { |pattern| user_agent.match?(pattern) } && !api_request?
      Rails.logger.warn "Suspicious User-Agent detected: #{user_agent}"
    end

    true
  end

  # 验证请求大小
  def validate_request_size
    content_length = request.content_length || 0
    max_size = max_request_size

    if content_length > max_size
      render_error_response(
        error: '请求体过大',
        error_code: 'REQUEST_TOO_LARGE',
        error_type: 'security_error',
        details: {
          max_size: "#{max_size / 1024 / 1024}MB",
          received_size: "#{content_length / 1024 / 1024}MB"
        },
        status: :payload_too_large
      )
      return false
    end

    true
  end

  # 验证可疑参数
  def validate_suspicious_params
    suspicious_patterns = [
      /<script/i, /javascript:/i, /vbscript:/i,
      /onload=/i, /onerror=/i, /onclick=/i,
      /union\s+select/i, /drop\s+table/i, /insert\s+into/i
    ]

    params.each do |key, value|
      next if value.is_a?(ActionController::Parameters)

      if value.is_a?(String) && suspicious_patterns.any? { |pattern| value.match?(pattern) }
        Rails.logger.warn "Suspicious parameter detected: #{key}=#{value[0..50]}"

        render_error_response(
          error: '请求包含可疑内容',
          error_code: 'SUSPICIOUS_CONTENT',
          error_type: 'security_error',
          status: :bad_request
        )
        return false
      end
    end

    true
  end

  # 验证请求模式
  def validate_request_pattern
    client_id = "#{request.remote_ip}:#{request.user_agent}"
    key = "request_pattern:#{Digest::MD5.hexdigest(client_id)}"

    # 获取最近请求时间
    recent_requests = Rails.cache.read(key) || []

    # 清理5分钟前的请求
    five_minutes_ago = 5.minutes.ago.to_f
    recent_requests.select! { |timestamp| timestamp > five_minutes_ago }

    # 检查是否存在异常请求模式
    if recent_requests.length > 50  # 5分钟内超过50个请求
      Rails.logger.warn "Suspicious request pattern detected: #{client_id}"

      render_error_response(
        error: '请求频率异常',
        error_code: 'SUSPICIOUS_PATTERN',
        error_type: 'security_error',
        details: {
          recent_requests: recent_requests.length,
          time_window: '5 minutes'
        },
        status: :too_many_requests
      )
      return false
    end

    # 记录当前请求时间
    recent_requests << Time.current.to_f
    Rails.cache.write(key, recent_requests, expires_in: 5.minutes)

    true
  end

  # 判断是否为敏感请求
  def sensitive_request?
    sensitive_endpoints = [
      /auth/, /login/, /register/, /password/,
      /admin/, /delete/, /update/, /create/
    ]

    sensitive_endpoints.any? { |pattern| request.path.match?(pattern) }
  end

  # 判断是否为API请求
  def api_request?
    request.path.start_with?('/api/')
  end

  # 获取最大请求大小
  def max_request_size
    case request.path
    when /upload/
      100.megabytes
    when /auth/
      1.megabyte
    else
      10.megabytes
    end
  end

  # 计算重试时间（简化版，现在限流服务提供有效的时间格式）
  def calculate_retry_after(reset_time)
    return 60 if reset_time.blank?

    begin
      # 限流服务现在总是提供有效的ISO8601格式时间字符串
      reset_timestamp = Time.parse(reset_time.to_s).to_i
      current_timestamp = Time.current.to_i
      [reset_timestamp - current_timestamp, 1].max
    rescue ArgumentError, TypeError => e
      Rails.logger.warn "时间解析错误: #{e.message}, reset_time: #{reset_time.inspect}"
      60
    end
  end

  # 记录API访问日志
  def log_api_access
    log_data = {
      request_id: @request_id,
      ip: request.remote_ip,
      method: request.method,
      path: request.path,
      status: response.status,
      user_id: current_user&.id,
      user_agent: request.user_agent,
      duration: measure_request_duration,
      response_size: response.body&.size || 0
    }

    Rails.logger.info "API Access: #{log_data.to_json}"

    # 记录到专门的访问日志（简化版）
    if Rails.application.config.respond_to?(:log_to_stdout) && Rails.application.config.log_to_stdout
      Rails.logger.info "API_ACCESS_DETAIL: #{log_data.to_json}"
    end
  end

  # 测量请求处理时间
  def measure_request_duration
    @request_start_time ||= Time.current
    ((Time.current - @request_start_time) * 1000).round(2)
  end

  # 渲染限流错误响应
  def render_rate_limit_error(limit:, remaining:, reset_time:, retry_after:, scope: nil)
    error_response = {
      success: false,
      error: 'API请求频率超过限制',
      error_code: 'RATE_LIMIT_EXCEEDED',
      error_type: 'rate_limit_error',
      timestamp: Time.current.iso8601,
      request_id: @request_id,
      details: {
        limit: limit,
        remaining: remaining,
        reset_time: reset_time,
        retry_after: retry_after,
        scope: scope
      },
      suggestions: [
        '请稍后重试',
        '如需更高限额，请联系管理员',
        '检查是否存在异常请求行为'
      ]
    }

    response.headers['Retry-After'] = retry_after.to_s
    response.headers['X-RateLimit-Limit'] = limit.to_s
    response.headers['X-RateLimit-Remaining'] = remaining.to_s
    response.headers['X-RateLimit-Reset'] = reset_time

    render json: error_response, status: :too_many_requests
  end

  # 渲染安全错误响应
  def render_security_error_response(message:, error_code:, details: {})
    error_response = {
      success: false,
      error: message,
      error_code: error_code,
      error_type: 'security_error',
      timestamp: Time.current.iso8601,
      request_id: @request_id,
      details: details,
      suggestions: [
        '请检查请求格式和内容',
        '确认请求来源可信',
        '如问题持续存在，请联系技术支持'
      ]
    }

    render json: error_response, status: :bad_request
  end

  # 生成API令牌（用于内部服务认证）
  def generate_api_token(service_name, expires_in: 1.hour)
    payload = {
      service: service_name,
      iat: Time.current.to_i,
      exp: (Time.current + expires_in).to_i,
      jti: SecureRandom.hex(16)
    }

    JWT.encode(payload, Rails.application.secrets.secret_key_base, 'HS256')
  end

  # 验证API令牌
  def verify_api_token(token)
    decoded = JWT.decode(
      token,
      Rails.application.secrets.secret_key_base,
      true,
      { algorithm: 'HS256' }
    ).first

    # 检查服务是否在允许列表中
    allowed_services = Rails.application.config.x.allowed_api_services || []
    unless allowed_services.include?(decoded['service'])
      raise JWT::VerificationError, 'Service not allowed'
    end

    decoded
  rescue JWT::ExpiredSignature
    raise JWT::ExpiredSignature, 'Token expired'
  rescue JWT::DecodeError
    raise JWT::DecodeError, 'Invalid token'
  end
end