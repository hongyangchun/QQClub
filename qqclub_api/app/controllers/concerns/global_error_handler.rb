# frozen_string_literal: true

# GlobalErrorHandler - 全局错误处理模块
# 为所有控制器提供统一的错误处理机制
module GlobalErrorHandler
  extend ActiveSupport::Concern

  included do
    # 全局异常处理
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found_error
    rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
    rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing_error
    rescue_from JWT::DecodeError, with: :handle_jwt_error
    rescue_from JWT::ExpiredSignature, with: :handle_jwt_expired_error
    rescue_from ActionController::BadRequest, with: :handle_bad_request_error
    rescue_from Timeout::Error, with: :handle_timeout_error
    rescue_from ActiveRecord::StatementInvalid, with: :handle_database_error
  end

  private

  def handle_standard_error(exception)
    handle_error(exception)
  end

  def handle_not_found_error(exception)
    handle_error(exception)
  end

  def handle_validation_error(exception)
    handle_error(exception)
  end

  def handle_parameter_missing_error(exception)
    handle_error(exception)
  end

  def handle_jwt_error(exception)
    handle_error(exception)
  end

  def handle_jwt_expired_error(exception)
    handle_error(exception)
  end

  def handle_bad_request_error(exception)
    handle_error(exception)
  end

  def handle_timeout_error(exception)
    handle_error(exception)
  end

  def handle_database_error(exception)
    handle_error(exception)
  end

  def handle_error(exception)
    # 使用全局错误处理服务
    error_handler = GlobalErrorHandlerService.handle_controller_exception(
      exception, self, action_name
    )

    # 记录错误信息
    log_error(error_handler)

    # 返回错误响应
    render_error_response(error_handler)
  end

  def log_error(error_handler)
    Rails.logger.error "Controller Error: #{error_handler.error_code} - " \
                      "Controller: #{self.class.name}, " \
                      "Action: #{action_name}, " \
                      "User ID: #{current_user&.id}, " \
                      "Error Details: #{error_handler.error_response}"
  end

  def render_error_response(error_handler)
    status = determine_http_status(error_handler.error_code)

    render json: error_handler.error_response, status: status
  rescue AbstractController::DoubleRenderError => e
    # 忽略双重渲染错误，避免无限循环
    Rails.logger.warn "DoubleRenderError caught in error handler: #{e.message}"
  end

  def determine_http_status(error_code)
    case error_code
    when 'RESOURCE_NOT_FOUND'
      :not_found
    when 'VALIDATION_ERROR', 'MISSING_PARAMETER', 'INVALID_PARAMETER'
      :unprocessable_entity
    when 'INVALID_TOKEN', 'TOKEN_EXPIRED'
      :unauthorized
    when 'TIMEOUT_ERROR', 'DATABASE_ERROR'
      :service_unavailable
    else
      :internal_server_error
    end
  end
end