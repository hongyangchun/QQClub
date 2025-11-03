# frozen_string_literal: true

# ServiceInterface - 服务接口规范模块
# 提供统一的服务接口和数据处理方法
module ServiceInterface
  extend ActiveSupport::Concern

  # 统一的数据访问方法
  def data
    @result
  end

  # 获取服务状态信息
  def status_info
    {
      success: success?,
      failure: failure?,
      errors: error_messages,
      has_errors: errors?,
      error_count: error_messages.count,
      first_error: first_error
    }
  end

  # 安全的数据获取（失败时返回默认值）
  def safe_data(default_value = nil)
    success? ? data : default_value
  end

  # 检查服务是否可用于当前用户
  def available_for_user?(user = nil)
    # 默认实现，子类可以重写
    true
  end

  # 获取服务类型标识
  def service_type
    self.class.name
  end

  # 获取服务描述
  def service_description
    self.class.name.demodulize.gsub(/Service$/, '')
  end

  # 批量操作结果格式化
  def format_batch_results(results, operation_name: '批量操作')
    successful_count = results.count { |r| r[:success] }
    failed_count = results.count - successful_count
    total_count = results.count

    {
      operation: operation_name,
      success: successful_count == total_count,
      summary: {
        total: total_count,
        successful: successful_count,
        failed: failed_count,
        success_rate: total_count > 0 ? (successful_count.to_f / total_count * 100).round(2) : 0
      },
      results: results
    }
  end

  protected

  # 验证用户权限
  def authorize_user!(user, required_permission = nil)
    return failure!("用户不能为空") unless user
    return failure!("用户不存在") unless user.persisted?

    if required_permission
      unless user.respond_to?(required_permission) && user.send(required_permission)
        return failure!("权限不足，需要权限: #{required_permission}")
      end
    end

    true
  end

  # 验证必需参数
  def validate_required_params(params, required_fields)
    missing_fields = required_fields.select { |field| params[field].blank? }

    if missing_fields.any?
      failure!("缺少必需参数: #{missing_fields.join(', ')}")
      return false
    end

    true
  end

  # 验证记录存在
  def validate_record_exists(record, name = '记录')
    unless record
      failure!("#{name}不存在")
      return false
    end

    unless record.persisted?
      failure!("#{name}未保存")
      return false
    end

    true
  end

  # 记录服务操作日志
  def log_service_action(action, additional_info = {})
    Rails.logger.info "Service #{service_type}: #{action} - #{additional_info}"
  end

  # 记录服务错误日志
  def log_service_error(error, additional_info = {})
    Rails.logger.error "Service #{service_type} Error: #{error.message}"
    Rails.logger.error additional_info if additional_info.any?
  end
end