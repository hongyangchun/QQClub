# frozen_string_literal: true

# ApplicationService - 所有Service的基类
# 提供统一的错误处理、成功/失败状态管理
class ApplicationService
  include ActiveModel::Model

  attr_reader :errors, :result

  def initialize
    @errors = []
    @success = false
    @result = nil
  end

  # 子类必须实现call方法
  def call
    raise NotImplementedError, "子类必须实现call方法"
  end

  # 标记操作成功
  def success!(result = nil)
    @success = true
    @result = result
    self
  end

  # 标记操作失败
  def failure!(error_messages)
    @success = false
    @errors = Array(error_messages)
    self
  end

  # 检查操作是否成功
  def success?
    @success
  end

  # 检查操作是否失败
  def failure?
    !@success
  end

  # 添加错误信息
  def add_error(message)
    @errors << message
  end

  # 检查是否有错误
  def errors?
    @errors.any?
  end

  # 获取第一个错误信息
  def first_error
    @errors.first
  end

  # 获取所有错误信息
  def error_messages
    @errors
  end

  # 获取错误信息（别名）
  def error_message
    @errors.first
  end

  # 清空错误信息
  def clear_errors!
    @errors = []
  end

  private

  # 块执行 - 统一异常处理
  def handle_errors
    yield
  rescue => e
    Rails.logger.error "Service Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    failure!("系统错误: #{e.message}")
  end

  # 验证必需参数
  def require_params!(params, required_keys)
    missing_keys = required_keys.select { |key| params[key].blank? }
    if missing_keys.any?
      failure!("缺少必需参数: #{missing_keys.join(', ')}")
      return false
    end
    true
  end

  # 验证对象存在
  def require_record!(record, error_message = "记录不存在")
    unless record
      failure!(error_message)
      return false
    end
    true
  end
end