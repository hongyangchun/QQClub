# frozen_string_literal: true

# ApiVersionable - API版本控制模块
# 为控制器提供API版本处理功能
module ApiVersionable
  extend ActiveSupport::Concern

  included do
    before_action :set_api_version
    before_action :validate_api_version
    before_action :add_version_headers
  end

  private

  # 设置API版本
  def set_api_version
    @api_version = ApiVersionService.determine_api_version(request)
    Thread.current[:api_version] = @api_version
  end

  # 验证API版本
  def validate_api_version
    return if ApiVersionService.version_supported?(@api_version)

    # 版本不支持时返回错误
    render_error(
      message: "不支持的API版本: #{@api_version}",
      error_code: 'unsupported_api_version',
      details: {
        requested_version: @api_version,
        supported_versions: ApiVersionService::SUPPORTED_VERSIONS,
        recommended_version: ApiVersionService::DEFAULT_VERSION
      },
      status_code: 400
    )
  end

  # 添加版本相关的响应头
  def add_version_headers
    return unless response

    headers = ApiVersionService.create_version_headers(@api_version, response.headers)
    headers.each do |key, value|
      response.headers[key] = value
    end

    # 如果版本已弃用，添加弃用警告到响应中
    if ApiVersionService.version_deprecated?(@api_version)
      deprecation_warning = ApiVersionService.generate_deprecation_warning(@api_version)
      response.headers['X-API-Deprecation-Warning'] = deprecation_warning[:message]
    end
  end

  # 获取当前API版本
  # @return [String] 当前API版本
  def current_api_version
    @api_version || ApiVersionService::DEFAULT_VERSION
  end

  # 检查是否为特定版本
  # @param version [String] 要检查的版本
  # @return [Boolean] 是否为指定版本
  def api_version?(version)
    current_api_version == version
  end

  # 检查版本是否为v1
  # @return [Boolean] 是否为v1
  def api_v1?
    api_version?('v1')
  end

  # 检查版本是否已弃用
  # @return [Boolean] 是否已弃用
  def api_version_deprecated?
    ApiVersionService.version_deprecated?(current_api_version)
  end

  # 获取版本信息
  # @return [Hash] 版本信息
  def current_version_info
    ApiVersionService.version_info(current_api_version)
  end

  # 根据版本条件执行代码块
  # @yield 如果版本匹配，执行给定的代码块
  # @param version [String] 要匹配的版本
  def with_api_version(version)
    yield if api_version?(version)
  end

  # 版本条件渲染
  # @param v1_response [Proc] v1版本的响应
  # @param default_response [Proc] 默认响应
  def render_by_version(v1_response: nil, default_response: nil)
    case current_api_version
    when 'v1'
      v1_response&.call || default_response&.call
    else
      default_response&.call
    end
  end

  # 版本化的参数处理
  # @param params_hash [Hash] 不同版本的参数映射
  # @return [Hash] 处理后的参数
  def versioned_params(params_hash = {})
    case current_api_version
    when 'v1'
      params_hash[:v1] || {}
    else
      params_hash[:default] || {}
    end
  end

  # 版本化的序列化选项
  # @param options_hash [Hash] 不同版本的选项映射
  # @return [Hash] 序列化选项
  def versioned_serialize_options(options_hash = {})
    base_options = {
      current_user: current_user,
      api_version: current_api_version
    }

    version_options = case current_api_version
                     when 'v1'
                       options_hash[:v1] || {}
                     else
                       options_hash[:default] || {}
                     end

    base_options.merge(version_options)
  end

  # 版本化的错误处理
  # @param error_hash [Hash] 不同版本的错误处理映射
  # @return [Hash] 错误响应
  def versioned_error_response(error_hash = {})
    base_error = {
      api_version: current_api_version,
      timestamp: Time.current.iso8601
    }

    version_error = case current_api_version
                    when 'v1'
                      error_hash[:v1] || {}
                    else
                      error_hash[:default] || {}
                    end

    base_error.merge(version_error)
  end

  # 检查功能是否在当前版本中可用
  # @param feature [String, Symbol] 功能名称
  # @return [Boolean] 功能是否可用
  def feature_available?(feature)
    case current_api_version
    when 'v1'
      available_features = [
        :user_authentication,
        :reading_events,
        :check_ins,
        :flowers,
        :comments,
        :notifications,
        :analytics,
        :content_search,
        :content_export
      ]
      available_features.include?(feature.to_sym)
    else
      false
    end
  end

  # 如果功能不可用，返回功能不支持错误
  # @param feature [String, Symbol] 功能名称
  # @param message [String] 自定义错误消息
  def check_feature_availability!(feature, message = nil)
    return if feature_available?(feature)

    feature_name = feature.to_s.humanize
    error_message = message || "功能 '#{feature_name}' 在API版本 #{current_api_version} 中不可用"

    render_error(
      message: error_message,
      error_code: 'feature_not_available',
      details: {
        feature: feature,
        api_version: current_api_version,
        available_in_version: find_feature_version(feature)
      },
      status_code: 501
    )
  end

  private

  # 查找功能可用的版本
  # @param feature [String, Symbol] 功能名称
  # @return [String, nil] 可用的版本
  def find_feature_version(feature)
    ApiVersionService::SUPPORTED_VERSIONS.find do |version|
      case version
      when 'v1'
        available_features = [
          :user_authentication,
          :reading_events,
          :check_ins,
          :flowers,
          :comments,
          :notifications,
          :analytics,
          :content_search,
          :content_export
        ]
        available_features.include?(feature.to_sym)
      end
    end
  end
end