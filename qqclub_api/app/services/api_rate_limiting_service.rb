# frozen_string_literal: true

# ApiRateLimitingService - API限流服务（简化版，无Redis依赖）
# 针对小用户量应用，直接允许所有请求通过
class ApiRateLimitingService < ApplicationService

  attr_reader :identifier, :limit, :window, :endpoint, :request

  def initialize(identifier:, limit: 1000, window: 1.hour, endpoint: nil, request: nil)
    super()
    @identifier = identifier
    @limit = limit
    @window = window
    @endpoint = endpoint
    @request = request
  end

  def call
    # 简化实现：直接允许所有请求通过
    @allowed = true
    @remaining_requests = limit
    @reset_time = (Time.current + window).iso8601
    @current_usage = 0

    Rails.logger.debug "Rate limiting disabled for small application"
    self
  end

  def allowed?
    @allowed
  end

  def remaining_requests
    @remaining_requests
  end

  def reset_time
    @reset_time
  end

  def current_usage
    @current_usage
  end

  # 类方法：检查用户限流（保持接口兼容性）
  def self.check_user_rate_limit(user, endpoint: nil, request: nil)
    identifier = "user:#{user.id}"
    limit = rate_limit_for_user(user, endpoint)
    window = rate_window_for_user(user, endpoint)

    new(
      identifier: identifier,
      limit: limit,
      window: window,
      endpoint: endpoint,
      request: request
    ).call
  end

  # 类方法：检查IP限流（保持接口兼容性）
  def self.check_ip_rate_limit(ip_address, endpoint: nil, request: nil)
    identifier = "ip:#{ip_address}"
    limit = rate_limit_for_ip(ip_address, endpoint)
    window = rate_window_for_ip(ip_address, endpoint)

    new(
      identifier: identifier,
      limit: limit,
      window: window,
      endpoint: endpoint,
      request: request
    ).call
  end

  # 类方法：检查全局限流（保持接口兼容性）
  def self.check_global_rate_limit(endpoint: nil, request: nil)
    identifier = "global"
    limit = rate_limit_for_global(endpoint)
    window = rate_window_for_global(endpoint)

    new(
      identifier: identifier,
      limit: limit,
      window: window,
      endpoint: endpoint,
      request: request
    ).call
  end

  # 保持向后兼容的统计方法
  def self.rate_limit_stats(identifier, window = 1.hour)
    {
      current_usage: 0,
      requests_in_window: [],
      peak_usage: 0,
      average_usage: 0.0,
      note: "Rate limiting is disabled for small applications"
    }
  end

  # 保持向后兼容的重置方法
  def self.reset_user_rate_limit(user_id)
    Rails.logger.debug "Rate limit reset for user #{user_id} (no-op)"
  end

  def self.reset_ip_rate_limit(ip_address)
    Rails.logger.debug "Rate limit reset for IP #{ip_address} (no-op)"
  end

  # 保持向后兼容的Redis检查方法
  def self.redis_available?
    false
  end

  # 保持向后兼容的配置方法
  def self.rate_limit_config
    {
      status: "disabled",
      note: "Rate limiting is disabled for small applications",
      user_limits: {
        admin: { limit: 1000, window: '5 minutes' },
        vip: { limit: 500, window: '1 hour' },
        premium: { limit: 200, window: '1 hour' },
        regular: { limit: 100, window: '1 hour' }
      },
      ip_limits: {
        trusted: { limit: 1000, window: '5 minutes' },
        regular: { limit: 50, window: '1 minute' }
      },
      global_limits: {
        auth: { limit: 20, window: '1 minute' },
        upload: { limit: 10, window: '1 minute' },
        default: { limit: 1000, window: '1 second' }
      }
    }
  end

  private

  # 保持向后兼容的限流规则方法
  def self.rate_limit_for_user(user, endpoint = nil)
    return 1000 if user&.admin?
    return 500 if user&.vip?
    return 200 if user&.premium?
    1000  # 小应用给更高的默认值
  end

  def self.rate_window_for_user(user, endpoint = nil)
    return 5.minutes if user&.admin?
    1.hour
  end

  def self.rate_limit_for_ip(ip_address, endpoint = nil)
    1000  # 小应用给更高的默认值
  end

  def self.rate_window_for_ip(ip_address, endpoint = nil)
    1.minute
  end

  def self.rate_limit_for_global(endpoint = nil)
    case endpoint
    when /auth/
      100   # 认证相关：100次/分钟
    when /upload/
      50    # 上传相关：50次/分钟
    else
      1000  # 全局：1000次/秒
    end
  end

  def self.rate_window_for_global(endpoint = nil)
    case endpoint
    when /auth/
      1.minute
    when /upload/
      1.minute
    else
      1.second
    end
  end
end