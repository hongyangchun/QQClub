# frozen_string_literal: true

module ApiResponse
  extend ActiveSupport::Concern

  # 成功响应
  def render_success(data = nil, message: nil, status: :ok)
    response = {
      success: true,
      data: data
    }
    response[:message] = message if message.present?

    render json: response, status: status
  end

  # 创建成功响应
  def render_created(data = nil, message: '创建成功')
    render_success(data, message: message, status: :created)
  end

  # 错误响应
  def render_error(message, errors: nil, status: :unprocessable_entity)
    response = {
      success: false,
      error: message
    }
    response[:errors] = errors if errors.present?

    render json: response, status: status
  end

  # 未找到响应
  def render_not_found(message = '资源不存在')
    render_error(message, status: :not_found)
  end

  # 权限不足响应
  def render_forbidden(message = '无权限访问')
    render_error(message, status: :forbidden)
  end

  # 未认证响应
  def render_unauthorized(message = '请先登录')
    render_error(message, status: :unauthorized)
  end

  # 分页响应
  def render_paginated(data, pagination_info = {}, message: nil)
    response = {
      success: true,
      data: data,
      pagination: pagination_info
    }
    response[:message] = message if message.present?

    render json: response
  end

  private

  # 构建分页信息
  def build_pagination_info(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value,
      has_next_page: collection.next_page.present?,
      has_prev_page: collection.prev_page.present?
    }
  end
end