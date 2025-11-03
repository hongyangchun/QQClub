# frozen_string_literal: true

# RequestValidator - 请求验证模块
# 提供统一的参数验证和请求安全检查
module RequestValidator
  extend ActiveSupport::Concern

  # 验证必需参数
  def validate_required_params(*param_names)
    missing_params = param_names.select { |param| params[param].blank? }

    if missing_params.any?
      render_parameter_error_response(
        parameter: missing_params.join(', '),
        message: "缺少必需的参数: #{missing_params.join(', ')}"
      )
      return false
    end

    true
  end

  # 验证参数类型
  def validate_param_type(param_name, expected_type)
    return true if params[param_name].blank?

    case expected_type.to_s.downcase
    when 'string'
      unless params[param_name].is_a?(String)
        render_parameter_error_response(
          parameter: param_name,
          message: "参数 #{param_name} 必须是字符串类型"
        )
        return false
      end
    when 'integer'
      unless params[param_name].to_s.match?(/\A\d+\z/)
        render_parameter_error_response(
          parameter: param_name,
          message: "参数 #{param_name} 必须是整数类型"
        )
        return false
      end
    when 'float', 'decimal'
      unless params[param_name].to_s.match?(/\A\d+(\.\d+)?\z/)
        render_parameter_error_response(
          parameter: param_name,
          message: "参数 #{param_name} 必须是数字类型"
        )
        return false
      end
    when 'boolean'
      unless %w[true false 1 0].include?(params[param_name].to_s.downcase)
        render_parameter_error_response(
          parameter: param_name,
          message: "参数 #{param_name} 必须是布尔类型"
        )
        return false
      end
    when 'array'
      unless params[param_name].is_a?(Array)
        render_parameter_error_response(
          parameter: param_name,
          message: "参数 #{param_name} 必须是数组类型"
        )
        return false
      end
    when 'hash', 'object'
      unless params[param_name].is_a?(Hash) || params[param_name].is_a?(ActionController::Parameters)
        render_parameter_error_response(
          parameter: param_name,
          message: "参数 #{param_name} 必须是对象类型"
        )
        return false
      end
    end

    true
  end

  # 验证参数长度
  def validate_param_length(param_name, min_length: nil, max_length: nil)
    value = params[param_name]
    return true if value.blank?

    length = value.to_s.length

    if min_length && length < min_length
      render_parameter_error_response(
        parameter: param_name,
        message: "参数 #{param_name} 长度不能少于 #{min_length} 个字符"
      )
      return false
    end

    if max_length && length > max_length
      render_parameter_error_response(
        parameter: param_name,
        message: "参数 #{param_name} 长度不能超过 #{max_length} 个字符"
      )
      return false
    end

    true
  end

  # 验证数值范围
  def validate_param_range(param_name, min_value: nil, max_value: nil)
    value = params[param_name]
    return true if value.blank?

    numeric_value = value.to_f

    if min_value && numeric_value < min_value
      render_parameter_error_response(
        parameter: param_name,
        message: "参数 #{param_name} 不能小于 #{min_value}"
      )
      return false
    end

    if max_value && numeric_value > max_value
      render_parameter_error_response(
        parameter: param_name,
        message: "参数 #{param_name} 不能大于 #{max_value}"
      )
      return false
    end

    true
  end

  # 验证日期格式
  def validate_date_format(param_name, format: :iso8601)
    value = params[param_name]
    return true if value.blank?

    begin
      case format
      when :iso8601
        Date.iso8601(value.to_s)
      when :date
        Date.parse(value.to_s)
      when :datetime
        DateTime.parse(value.to_s)
      else
        Date.parse(value.to_s)
      end
    rescue ArgumentError
      render_parameter_error_response(
        parameter: param_name,
        message: "参数 #{param_name} 日期格式不正确，请使用 #{format} 格式"
      )
      return false
    end

    true
  end

  # 验证邮箱格式
  def validate_email_format(param_name)
    value = params[param_name]
    return true if value.blank?

    email_regex = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

    unless value.match?(email_regex)
      render_parameter_error_response(
        parameter: param_name,
        message: "参数 #{param_name} 邮箱格式不正确"
      )
      return false
    end

    true
  end

  # 验证URL格式
  def validate_url_format(param_name)
    value = params[param_name]
    return true if value.blank?

    uri = URI.parse(value)
    unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      render_parameter_error_response(
        parameter: param_name,
        message: "参数 #{param_name} URL格式不正确"
      )
      return false
    end

    true
  rescue URI::InvalidURIError
    render_parameter_error_response(
      parameter: param_name,
      message: "参数 #{param_name} URL格式不正确"
    )
    false
  end

  # 验证枚举值
  def validate_enum_values(param_name, allowed_values)
    value = params[param_name]
    return true if value.blank?

    unless allowed_values.include?(value)
      render_parameter_error_response(
        parameter: param_name,
        message: "参数 #{param_name} 必须是以下值之一: #{allowed_values.join(', ')}"
      )
      return false
    end

    true
  end

  # 验证分页参数
  def validate_pagination_params
    # 验证页码
    if params[:page].present?
      unless validate_param_type(:page, 'integer')
        return false
      end

      unless validate_param_range(:page, min_value: 1)
        return false
      end
    end

    # 验证每页数量
    if params[:per_page].present?
      unless validate_param_type(:per_page, 'integer')
        return false
      end

      unless validate_param_range(:per_page, min_value: 1, max_value: 100)
        return false
      end
    end

    # 设置默认值
    params[:page] ||= 1
    params[:per_page] ||= 20

    true
  end

  # 验证排序参数
  def validate_sort_params(allowed_fields = nil)
    if params[:sort_by].present?
      # 验证排序字段
      if allowed_fields && !allowed_values.include?(params[:sort_by])
        render_parameter_error_response(
          parameter: 'sort_by',
          message: "排序字段必须是以下值之一: #{allowed_fields.join(', ')}"
        )
        return false
      end

      # 验证排序方向
      if params[:sort_direction].present?
        unless validate_enum_values(:sort_direction, ['asc', 'desc'])
          return false
        end
      else
        params[:sort_direction] = 'desc'
      end
    end

    true
  end

  # 验证文件上传
  def validate_file_upload(param_name, max_size: nil, allowed_types: nil)
    file = params[param_name]
    return true if file.blank?

    # 验证文件大小
    if max_size && file.size > max_size
      render_parameter_error_response(
        parameter: param_name,
        message: "文件大小不能超过 #{max_size / 1024 / 1024}MB"
      )
      return false
    end

    # 验证文件类型
    if allowed_types && !allowed_types.include?(file.content_type)
      render_parameter_error_response(
        parameter: param_name,
        message: "文件类型必须是以下类型之一: #{allowed_types.join(', ')}"
      )
      return false
    end

    true
  end

  # 验证批量操作参数
  def validate_batch_operation_params
    unless validate_required_params(:ids)
      return false
    end

    unless validate_param_type(:ids, 'array')
      return false
    end

    if params[:ids].length > 100
      render_parameter_error_response(
        parameter: 'ids',
        message: "批量操作最多支持100个项目"
      )
      return false
    end

    true
  end

  # 验证JSON格式
  def validate_json_param(param_name)
    value = params[param_name]
    return true if value.blank?

    begin
      JSON.parse(value.to_s)
    rescue JSON::ParserError
      render_parameter_error_response(
        parameter: param_name,
        message: "参数 #{param_name} 必须是有效的JSON格式"
      )
      return false
    end

    true
  end

  # 验证时间范围
  def validate_time_range(start_param, end_param)
    if params[start_param].present? && params[end_param].present?
      unless validate_date_format(start_param) && validate_date_format(end_param)
        return false
      end

      start_time = params[start_param].to_s
      end_time = params[end_param].to_s

      if Time.parse(end_time) < Time.parse(start_time)
        render_parameter_error_response(
          parameter: end_param,
          message: "结束时间不能早于开始时间"
        )
        return false
      end
    end

    true
  end

  # 综合验证方法
  def validate_request_params(validations = {})
    validations.each do |param_name, options|
      # 验证必需参数
      if options[:required] && params[param_name].blank?
        render_parameter_error_response(
          parameter: param_name,
          message: "缺少必需的参数: #{param_name}"
        )
        return false
      end

      # 跳过空值的后续验证
      next if params[param_name].blank?

      # 验证类型
      if options[:type] && !validate_param_type(param_name, options[:type])
        return false
      end

      # 验证长度
      if options[:length] && !validate_param_length(param_name, **options[:length])
        return false
      end

      # 验证范围
      if options[:range] && !validate_param_range(param_name, **options[:range])
        return false
      end

      # 验证格式
      if options[:format] == :email && !validate_email_format(param_name)
        return false
      elsif options[:format] == :url && !validate_url_format(param_name)
        return false
      elsif options[:format] == :json && !validate_json_param(param_name)
        return false
      end

      # 验证枚举值
      if options[:in] && !validate_enum_values(param_name, options[:in])
        return false
      end
    end

    true
  end
end