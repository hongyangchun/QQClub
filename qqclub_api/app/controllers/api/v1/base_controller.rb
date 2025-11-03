require 'digest'

class Api::V1::BaseController < ActionController::API
  # 添加JSON支持
  include ActionController::MimeResponds
  # 添加API版本控制
  include ApiVersionable
  # 添加全局错误处理
  include GlobalErrorHandler
  # 添加API响应格式化
  include ApiResponseFormatter
  # 添加请求验证
  include RequestValidator
  # 添加API安全增强
  include ApiSecurity
  # 添加用户体验增强
  include UserExperienceEnhancer

  private

  # 统一成功响应格式 - 使用 ApiResponseService
  def render_success(data: nil, message: '操作成功', meta: {}, status_code: 200)
    response, status = ApiResponseService.success_response(
      data: data,
      message: message,
      meta: meta,
      status_code: status_code
    )
    render json: response, status: status
  end

  # 统一错误响应格式 - 使用 ApiResponseService
  def render_error(message: '操作失败', error_code: nil, details: {}, status_code: 400)
    response, status = ApiResponseService.error_response(
      message: message,
      error_code: error_code,
      details: details,
      status_code: status_code
    )
    render json: response, status: status
  end

  # 验证错误响应
  def render_validation_error(errors, message: '请求参数验证失败')
    response, status = ApiResponseService.validation_error_response(errors, message: message)
    render json: response, status: status
  end

  # 未找到错误响应
  def render_not_found(resource_type: '资源', resource_id: nil)
    response, status = ApiResponseService.not_found_response(
      resource_type: resource_type,
      resource_id: resource_id
    )
    render json: response, status: status
  end

  # 权限错误响应
  def render_authorization_error(message: '权限不足', required_permission: nil)
    response, status = ApiResponseService.authorization_error_response(
      message: message,
      required_permission: required_permission
    )
    render json: response, status: status
  end

  # 认证错误响应
  def render_authentication_error(message: '认证失败', details: {})
    response, status = ApiResponseService.authentication_error_response(
      message: message,
      details: details
    )
    render json: response, status: status
  end

  # 服务不可用错误响应
  def render_service_unavailable(service_name: '服务', retry_after: 30)
    response, status = ApiResponseService.service_unavailable_response(
      service_name: service_name,
      retry_after: retry_after
    )
    render json: response, status: status
  end

  # 限流错误响应
  def render_rate_limit_error(limit_info = {})
    response, status = ApiResponseService.rate_limit_error_response(limit_info)
    render json: response, status: status
  end

  # 分页响应
  def render_paginated(records:, pagination:, message: '获取成功', additional_meta: {})
    response, status = ApiResponseService.paginated_response(
      records: records,
      pagination: pagination,
      message: message,
      additional_meta: additional_meta
    )
    render json: response, status: status
  end

  # 创建成功响应
  def render_create_success(resource, resource_name: '资源')
    response, status = ApiResponseService.create_success_response(
      resource,
      resource_name: resource_name
    )
    render json: response, status: status
  end

  # 更新成功响应
  def render_update_success(resource, resource_name: '资源')
    response, status = ApiResponseService.update_success_response(
      resource,
      resource_name: resource_name
    )
    render json: response, status: status
  end

  # 删除成功响应
  def render_destroy_success(resource_name: '资源')
    response, status = ApiResponseService.destroy_success_response(
      resource_name: resource_name
    )
    render json: response, status: status
  end

  # 批量操作响应
  def render_batch_operation(results, operation_name: '批量操作')
    response, status = ApiResponseService.batch_operation_response(
      results,
      operation_name: operation_name
    )
    render json: response, status: status
  end

  # 健康检查响应
  def render_health_check(additional_info = {})
    response, status = ApiResponseService.health_response(additional_info)
    render json: response, status: status
  end

  # 当前用户认证
  def authenticate_user!
    auth_header = request.headers['Authorization']
    token = auth_header&.split(' ')&.last

    unless token
      render_authentication_error(
        message: '请先登录',
        details: { reason: 'missing_token', required_format: 'Bearer <token>' }
      )
      return false
    end

    decoded = User.decode_jwt_token(token)
    unless decoded
      render_authentication_error(
        message: '认证令牌无效',
        details: { reason: 'invalid_token', token_provided: token[0..20] + '...' }
      )
      return false
    end

    @current_user = User.find_by(id: decoded['user_id'])

    unless @current_user
      render_authentication_error(
        message: '用户不存在',
        details: { reason: 'user_not_found', user_id: decoded['user_id'] }
      )
      return false
    end

    true
  rescue => e
    Rails.logger.error "Authentication error: #{e.message}"
    render_authentication_error(
      message: '认证失败',
      details: { reason: 'processing_error', error: e.message }
    )
    false
  end

  # 权限检查 - 必须是活动创建者
  def authorize_event_leader!
    unless @current_user == @reading_event&.leader
      render_authorization_error(
        message: '权限不足，只有活动创建者可以执行此操作',
        required_permission: 'event_leader'
      )
    end
  end

  # 权限检查 - 必须是管理员
  def authorize_admin!
    unless @current_user&.admin?
      render_authorization_error(
        message: '权限不足，只有管理员可以执行此操作',
        required_permission: 'admin_access'
      )
    end
  end

  # 分页参数处理
  def pagination_params
    {
      page: params[:page]&.to_i || 1,
      per_page: [params[:per_page]&.to_i || 20, 100].min
    }
  end

  # 排序参数处理
  def sorting_params(default_field: :created_at, default_direction: :desc)
    {
      sort_field: params[:sort]&.to_sym || default_field,
      sort_direction: params[:direction]&.to_sym || default_direction
    }
  end

  # 构建分页元数据
  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      per_page: collection.limit_value,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      next_page: collection.next_page,
      prev_page: collection.prev_page
    }
  end

  # 安全的参数检查
  def safe_integer_param(param_name, default_value: 0)
    value = params[param_name]
    return default_value if value.blank?

    begin
      value.to_i
    rescue ArgumentError, TypeError
      default_value
    end
  end

  def safe_decimal_param(param_name, default_value: 0.0)
    value = params[param_name]
    return default_value if value.blank?

    begin
      BigDecimal(value.to_s)
    rescue ArgumentError, TypeError
      default_value
    end
  end

  def safe_date_param(param_name)
    value = params[param_name]
    return nil if value.blank?

    begin
      Date.parse(value)
    rescue ArgumentError
      nil
    end
  end

  def safe_datetime_param(param_name)
    value = params[param_name]
    return nil if value.blank?

    begin
      DateTime.parse(value)
    rescue ArgumentError
      nil
    end
  end

  # 当前用户
  def current_user
    @current_user
  end

  # 记录API调用日志
  def log_api_call(action, result = 'success')
    Rails.logger.info "API Call: #{action} by User #{current_user&.id} - #{result}"
  end

  # 参数验证辅助方法
  def validate_required_fields(*fields)
    missing_fields = fields.select { |field| params[field].blank? }

    if missing_fields.any?
      error_messages = missing_fields.map { |field| "#{field} 不能为空" }
      render_validation_error(
        error_messages,
        message: '缺少必要参数'
      )
      return false
    end

    true
  end
end