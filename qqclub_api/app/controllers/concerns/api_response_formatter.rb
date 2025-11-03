# frozen_string_literal: true

# ApiResponseFormatter - API响应格式化模块
# 提供统一的API响应格式和成功响应处理
module ApiResponseFormatter
  extend ActiveSupport::Concern

  # 成功响应格式
  def render_success_response(data: nil, message: 'Success', meta: {})
    response_data = {
      success: true,
      message: message,
      data: data,
      timestamp: Time.current.iso8601,
      request_id: request&.request_id || SecureRandom.uuid
    }

    # 添加元数据
    response_data[:meta] = meta if meta.any?

    render json: response_data, status: :ok
  end

  # 分页响应格式
  def render_paginated_response(data:, pagination:, message: 'Success', meta: {})
    pagination_meta = {
      current_page: pagination[:current_page],
      per_page: pagination[:per_page],
      total_count: pagination[:total_count],
      total_pages: pagination[:total_pages]
    }

    # 添加cursor分页信息
    if pagination[:next_cursor]
      pagination_meta[:next_cursor] = pagination[:next_cursor]
    end
    if pagination[:prev_cursor]
      pagination_meta[:prev_cursor] = pagination[:prev_cursor]
    end

    response_data = {
      success: true,
      message: message,
      data: data,
      pagination: pagination_meta,
      timestamp: Time.current.iso8601,
      request_id: request&.request_id || SecureRandom.uuid
    }

    response_data[:meta] = meta if meta.any?

    render json: response_data, status: :ok
  end

  # 创建成功响应
  def render_created_response(data: nil, message: 'Created successfully', location: nil)
    response_data = {
      success: true,
      message: message,
      data: data,
      timestamp: Time.current.iso8601,
      request_id: request&.request_id || SecureRandom.uuid
    }

    # 设置Location头
    headers['Location'] = location if location

    render json: response_data, status: :created
  end

  # 更新成功响应
  def render_updated_response(data: nil, message: 'Updated successfully')
    response_data = {
      success: true,
      message: message,
      data: data,
      timestamp: Time.current.iso8601,
      request_id: request&.request_id || SecureRandom.uuid
    }

    render json: response_data, status: :ok
  end

  # 删除成功响应
  def render_deleted_response(message: 'Deleted successfully')
    response_data = {
      success: true,
      message: message,
      timestamp: Time.current.iso8601,
      request_id: request&.request_id || SecureRandom.uuid
    }

    render json: response_data, status: :ok
  end

  # 无内容响应
  def render_no_content_response(message: 'No content')
    head :no_content
  end

  # 批量操作响应
  def render_batch_response(results:, message: 'Batch operation completed')
    success_count = results.count { |r| r[:success] }
    error_count = results.count { |r| !r[:success] }

    response_data = {
      success: true,
      message: message,
      data: {
        total: results.length,
        success_count: success_count,
        error_count: error_count,
        results: results
      },
      timestamp: Time.current.iso8601,
      request_id: request&.request_id || SecureRandom.uuid
    }

    render json: response_data, status: :ok
  end

  # 验证错误响应（用于手动验证）
  def render_validation_errors_response(errors:, message: 'Validation failed')
    error_response = {
      success: false,
      error: message,
      error_code: 'VALIDATION_ERROR',
      error_type: 'validation_error',
      errors: errors.is_a?(Hash) ? errors.values.flatten : errors,
      timestamp: Time.current.iso8601,
      request_id: request&.request_id || SecureRandom.uuid,
      details: {
        suggestions: [
          '请检查必填字段是否完整',
          '确认数据格式是否正确',
          '参考API文档确认参数要求'
        ]
      }
    }

    render json: error_response, status: :unprocessable_entity
  end

  # 参数错误响应（用于手动参数验证）
  def render_parameter_error_response(parameter:, message: nil)
    error_message = message || "参数错误: #{parameter}"

    error_response = {
      success: false,
      error: error_message,
      error_code: 'INVALID_PARAMETER',
      error_type: 'parameter_error',
      timestamp: Time.current.iso8601,
      request_id: request&.request_id || SecureRandom.uuid,
      details: {
        parameter: parameter,
        suggestions: [
          '请检查请求参数格式',
          '参考API文档确认参数要求',
          '确保参数值符合预期类型和范围'
        ]
      }
    }

    render json: error_response, status: :unprocessable_entity
  end

  # 权限错误响应（用于手动权限检查）
  def render_permission_denied_response(message: 'Permission denied')
    error_response = {
      success: false,
      error: message,
      error_code: 'PERMISSION_DENIED',
      error_type: 'authorization_error',
      timestamp: Time.current.iso8601,
      request_id: request&.request_id || SecureRandom.uuid,
      details: {
        user_id: current_user&.id,
        user_role: current_user&.role_as_string,
        suggestions: [
          '请确认您有足够的权限执行此操作',
          '如需权限提升，请联系管理员',
          '检查用户账户状态是否正常'
        ]
      }
    }

    render json: error_response, status: :forbidden
  end

  # 资源不存在响应（用于手动检查）
  def render_not_found_response(resource: 'Resource', message: nil)
    error_message = message || "#{resource} not found"

    error_response = {
      success: false,
      error: error_message,
      error_code: 'RESOURCE_NOT_FOUND',
      error_type: 'not_found',
      timestamp: Time.current.iso8601,
      request_id: request&.request_id || SecureRandom.uuid,
      details: {
        resource: resource,
        suggestions: [
          '请检查资源ID是否正确',
          '确认资源是否存在且未被删除',
          '检查URL路径是否正确'
        ]
      }
    }

    render json: error_response, status: :not_found
  end

  private

  # 构建标准元数据
  def build_meta_data(additional_meta = {})
    base_meta = {
      version: api_version,
      environment: Rails.env
    }

    base_meta.merge(additional_meta)
  end

  # 获取API版本
  def api_version
    if request.path.start_with?('/api/v1/')
      'v1'
    else
      'v0'
    end
  end
end