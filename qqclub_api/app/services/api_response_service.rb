# frozen_string_literal: true

# ApiResponseService - API响应标准化服务
# 提供统一的API响应格式，包括成功响应、错误响应、分页响应等
class ApiResponseService
  include ActionView::Helpers::NumberHelper

  # 尝试加载 RequestStore，如果不存在则跳过
  begin
    require 'request_store'
  rescue LoadError
    # RequestStore gem 没有安装，使用简单的替代方案
  end

  class << self
    # 标准成功响应
    # @param data [Object] 响应数据
    # @param message [String] 响应消息
    # @param meta [Hash] 元数据
    # @param status_code [Integer] HTTP状态码
    # @return [Hash] 标准化的响应格式
    def success_response(data: nil, message: '操作成功', meta: {}, status_code: 200)
      response = {
        success: true,
        message: message,
        data: data,
        meta: standard_meta(meta),
        timestamp: Time.current.iso8601
      }

      # 添加请求ID（如果存在）
      add_request_id(response)

      [response, status_code]
    end

    # 标准错误响应
    # @param message [String] 错误消息
    # @param error_code [String] 错误代码
    # @param details [Hash] 错误详情
    # @param status_code [Integer] HTTP状态码
    # @return [Hash] 标准化的错误响应格式
    def error_response(message: '操作失败', error_code: nil, details: {}, status_code: 400)
      response = {
        success: false,
        message: message,
        error_code: error_code,
        data: nil,
        meta: standard_meta,
        timestamp: Time.current.iso8601
      }

      # 添加错误详情（开发环境）
      if Rails.env.development? && details.any?
        response[:details] = details
      end

      # 添加请求ID（如果存在）
      add_request_id(response)

      [response, status_code]
    end

    # 验证错误响应
    # @param errors [ActiveModel::Errors] 验证错误对象
    # @param message [String] 响应消息
    # @return [Hash] 标准化的验证错误响应格式
    def validation_error_response(errors, message: '请求参数验证失败')
      error_details = if errors.respond_to?(:details)
                       errors.details.transform_values do |details|
                         details.map { |detail| detail[:error].to_s.humanize }
                       end
                     else
                       errors.is_a?(Hash) ? errors : { base: [errors.to_s] }
                     end

      error_response(
        message: message,
        error_code: 'validation_error',
        details: { errors: error_details },
        status_code: 422
      )
    end

    # 未找到错误响应
    # @param resource_type [String] 资源类型
    # @param resource_id [String, Integer] 资源ID
    # @return [Hash] 标准化的未找到响应格式
    def not_found_response(resource_type: '资源', resource_id: nil)
      message = if resource_id
                  "#{resource_type} (ID: #{resource_id}) 不存在"
                else
                  "#{resource_type} 不存在"
                end

      error_response(
        message: message,
        error_code: 'not_found',
        status_code: 404
      )
    end

    # 权限错误响应
    # @param message [String] 错误消息
    # @param required_permission [String] 需要的权限
    # @return [Hash] 标准化的权限错误响应格式
    def authorization_error_response(message: '权限不足', required_permission: nil)
      details = {}
      details[:required_permission] = required_permission if required_permission

      error_response(
        message: message,
        error_code: 'authorization_error',
        details: details,
        status_code: 403
      )
    end

    # 认证错误响应
    # @param message [String] 错误消息
    # @param details [Hash] 错误详情
    # @return [Hash] 标准化的认证错误响应格式
    def authentication_error_response(message: '认证失败', details: {})
      error_response(
        message: message,
        error_code: 'authentication_error',
        details: details,
        status_code: 401
      )
    end

    # 服务不可用错误响应
    # @param service_name [String] 服务名称
    # @param retry_after [Integer] 建议重试时间（秒）
    # @return [Hash] 标准化的服务不可用响应格式
    def service_unavailable_response(service_name: '服务', retry_after: 30)
      message = "#{service_name}暂时不可用，请稍后再试"

      response, = error_response(
        message: message,
        error_code: 'service_unavailable',
        status_code: 503
      )

      # 添加重试信息
      response[:meta][:retry_after] = retry_after

      [response, 503]
    end

    # 限流错误响应
    # @param limit_info [Hash] 限流信息
    # @return [Hash] 标准化的限流错误响应格式
    def rate_limit_error_response(limit_info = {})
      message = '请求过于频繁，请稍后再试'

      response, = error_response(
        message: message,
        error_code: 'rate_limit_exceeded',
        status_code: 429
      )

      # 添加限流信息
      response[:meta].merge!(limit_info) if limit_info.any?

      [response, 429]
    end

    # 分页响应
    # @param records [Array] 记录数组
    # @param pagination [Hash] 分页信息
    # @param message [String] 响应消息
    # @param additional_meta [Hash] 额外的元数据
    # @return [Hash] 标准化的分页响应格式
    def paginated_response(records:, pagination:, message: '获取成功', additional_meta: {})
      meta = standard_meta(pagination.merge(additional_meta))

      success_response(
        data: records,
        message: message,
        meta: meta
      )
    end

    # 创建成功响应
    # @param resource [Object] 创建的资源
    # @param resource_name [String] 资源名称
    # @return [Hash] 标准化的创建成功响应格式
    def create_success_response(resource, resource_name: '资源')
      message = "#{resource_name}创建成功"

      success_response(
        data: resource,
        message: message,
        status_code: 201
      )
    end

    # 更新成功响应
    # @param resource [Object] 更新的资源
    # @param resource_name [String] 资源名称
    # @return [Hash] 标准化的更新成功响应格式
    def update_success_response(resource, resource_name: '资源')
      message = "#{resource_name}更新成功"

      success_response(
        data: resource,
        message: message
      )
    end

    # 删除成功响应
    # @param resource_name [String] 资源名称
    # @return [Hash] 标准化的删除成功响应格式
    def destroy_success_response(resource_name: '资源')
      message = "#{resource_name}删除成功"

      success_response(
        data: nil,
        message: message
      )
    end

    # 批量操作响应
    # @param results [Hash] 批量操作结果
    # @param operation_name [String] 操作名称
    # @return [Hash] 标准化的批量操作响应格式
    def batch_operation_response(results, operation_name: '批量操作')
      successful_count = results[:successful]&.count || 0
      failed_count = results[:failed]&.count || 0
      total_count = results[:total] || successful_count + failed_count

      if failed_count == 0
        message = "#{operation_name}全部成功 (#{successful_count}/#{total_count})"
      elsif successful_count == 0
        message = "#{operation_name}全部失败 (0/#{total_count})"
      else
        message = "#{operation_name}部分成功 (#{successful_count}/#{total_count})"
      end

      success_response(
        data: results,
        message: message,
        meta: {
          successful_count: successful_count,
          failed_count: failed_count,
          total_count: total_count,
          success_rate: total_count > 0 ? (successful_count.to_f / total_count * 100).round(1) : 0
        }
      )
    end

    # 健康检查响应
    # @param additional_info [Hash] 额外的健康信息
    # @return [Hash] 健康检查响应格式
    def health_response(additional_info = {})
      health_data = {
        status: 'healthy',
        timestamp: Time.current.iso8601,
        environment: Rails.env,
        version: Rails.application.config.version || '1.0.0',
        uptime: number_to_human(Time.current - Rails.application.booted_at),
        memory_usage: number_to_human_size(`ps -o rss= -p #{Process.pid}`.to_i)
      }

      health_data.merge!(additional_info) if additional_info.any?

      success_response(
        data: health_data,
        message: '服务运行正常'
      )
    end

    private

    # 标准化元数据
    # @param meta [Hash] 原始元数据
    # @return [Hash] 标准化的元数据
    def standard_meta(meta = {})
      {
        version: (Rails.application.config.api_version rescue nil) || 'v1',
        server_time: Time.current.iso8601
      }.merge(meta)
    end

    # 添加请求ID到响应中
    # @param response [Hash] 响应对象
    def add_request_id(response)
      request_id = if defined?(RequestStore)
                     RequestStore.store[:request_id]
                   else
                     Thread.current[:request_id]
                   end
      response[:request_id] = request_id if request_id
    end
  end
end