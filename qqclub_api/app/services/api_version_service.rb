# frozen_string_literal: true

# ApiVersionService - API版本控制服务
# 提供API版本管理、兼容性处理和版本信息查询
class ApiVersionService
  # 当前支持的API版本
  SUPPORTED_VERSIONS = %w[v1].freeze

  # 默认API版本
  DEFAULT_VERSION = 'v1'.freeze

  # 版本弃用时间（天）
  DEPRECATION_DAYS = 90.freeze

  class << self
    # 从请求中确定API版本
    # @param request [ActionDispatch::Request] HTTP请求对象
    # @param available_versions [Array] 可用的版本列表
    # @return [String] 确定的API版本
    def determine_api_version(request, available_versions = SUPPORTED_VERSIONS)
      # 1. 从URL路径获取版本
      version_from_path = extract_version_from_path(request.path)
      return version_from_path if available_versions.include?(version_from_path)

      # 2. 从请求头获取版本
      version_from_header = request.headers['API-Version'] || request.headers['X-API-Version']
      return version_from_header if available_versions.include?(version_from_header)

      # 3. 从查询参数获取版本
      version_from_params = request.params['api_version'] || request.params['version']
      return version_from_params if available_versions.include?(version_from_params)

      # 4. 返回默认版本
      DEFAULT_VERSION
    end

    # 检查版本是否支持
    # @param version [String] 版本号
    # @param available_versions [Array] 可用的版本列表
    # @return [Boolean] 是否支持
    def version_supported?(version, available_versions = SUPPORTED_VERSIONS)
      available_versions.include?(version)
    end

    # 获取版本信息
    # @param version [String] 版本号
    # @return [Hash] 版本信息
    def version_info(version = DEFAULT_VERSION)
      version_configs = {
        'v1' => {
          version: 'v1',
          name: 'QQClub API v1.0',
          description: 'QQClub读书会平台API的第一个稳定版本',
          release_date: '2025-10-15',
          status: 'stable',
          deprecated: false,
          sunset_date: nil,
          features: [
            '用户认证和授权',
            '共读活动管理',
            '打卡和进度跟踪',
            '小红花激励机制',
            '评论和互动系统',
            '通知系统',
            '内容搜索和导出',
            '数据统计分析'
          ],
          endpoints: {
            auth: [
              'POST /api/auth/mock_login',
              'POST /api/auth/wechat_login',
              'POST /api/auth/refresh_token',
              'GET /api/auth/me'
            ],
            events: [
              'GET /api/v1/reading_events',
              'POST /api/v1/reading_events',
              'GET /api/v1/reading_events/:id',
              'PUT /api/v1/reading_events/:id',
              'DELETE /api/v1/reading_events/:id'
            ],
            check_ins: [
              'POST /api/v1/check_ins',
              'GET /api/v1/check_ins',
              'GET /api/v1/check_ins/:id'
            ],
            flowers: [
              'POST /api/v1/flowers',
              'GET /api/v1/flowers',
              'GET /api/v1/flower_leaderboards'
            ],
            notifications: [
              'GET /api/v1/notifications',
              'POST /api/v1/notifications/mark_all_read'
            ],
            analytics: [
              'GET /api/v1/analytics/overview',
              'GET /api/v1/analytics/dashboard'
            ]
          }
        }
      }

      version_configs[version] || {
        version: version,
        name: "Unknown Version",
        description: "版本信息未知",
        status: 'unknown',
        deprecated: false
      }
    end

    # 获取所有版本信息
    # @return [Array] 所有版本的详细信息
    def all_versions_info
      SUPPORTED_VERSIONS.map { |version| version_info(version) }
    end

    # 检查版本是否已弃用
    # @param version [String] 版本号
    # @return [Boolean] 是否已弃用
    def version_deprecated?(version)
      version_info(version)[:deprecated]
    end

    # 获取版本弃用信息
    # @param version [String] 版本号
    # @return [Hash] 弃用信息
    def deprecation_info(version)
      info = version_info(version)

      if info[:deprecated]
        {
          version: version,
          deprecated: true,
          sunset_date: info[:sunset_date],
          migration_guide: info[:migration_guide],
          alternative_versions: SUPPORTED_VERSIONS.reject { |v| v == version }
        }
      else
        {
          version: version,
          deprecated: false
        }
      end
    end

    # 创建版本响应头
    # @param version [String] 当前版本
    # @param response_headers [Hash] 响应头
    # @return [Hash] 更新后的响应头
    def create_version_headers(version, response_headers = {})
      headers = response_headers.dup

      # API版本信息
      headers['API-Version'] = version
      headers['Supported-Versions'] = SUPPORTED_VERSIONS.join(',')

      # 如果版本已弃用，添加弃用警告
      if version_deprecated?(version)
        headers['Deprecation'] = 'true'
        headers['Sunset'] = version_info(version)[:sunset_date] if version_info(version)[:sunset_date]
        headers['Migration-Guide'] = version_info(version)[:migration_guide] if version_info(version)[:migration_guide]
      end

      headers
    end

    # 生成版本弃用通知
    # @param version [String] 弃用的版本
    # @return [Hash] 弃用通知信息
    def generate_deprecation_warning(version)
      info = version_info(version)

      {
        warning: "API版本 #{version} 已弃用",
        message: "请升级到更新的API版本以获得更好的服务和功能",
        sunset_date: info[:sunset_date],
        days_until_sunset: info[:sunset_date] ? ((Date.parse(info[:sunset_date]) - Date.current).to_i) : nil,
        migration_guide: info[:migration_guide],
        recommended_version: DEFAULT_VERSION,
        supported_versions: SUPPORTED_VERSIONS.reject { |v| v == version }
      }
    end

    # 验证版本兼容性
    # @param requested_version [String] 请求的版本
    # @param available_versions [Array] 可用版本
    # @return [Hash] 兼容性检查结果
    def check_version_compatibility(requested_version, available_versions = SUPPORTED_VERSIONS)
      result = {
        requested_version: requested_version,
        compatible: false,
        supported: false,
        deprecated: false,
        recommended_version: DEFAULT_VERSION,
        messages: []
      }

      # 检查版本是否支持
      if version_supported?(requested_version, available_versions)
        result[:supported] = true
        result[:compatible] = true

        # 检查是否已弃用
        if version_deprecated?(requested_version)
          result[:deprecated] = true
          result[:messages] << "版本 #{requested_version} 已弃用，建议升级到 #{DEFAULT_VERSION}"

          deprecation_info = generate_deprecation_warning(requested_version)
          result[:deprecation_warning] = deprecation_info
        end
      else
        result[:messages] << "不支持的API版本: #{requested_version}"
        result[:messages] << "支持的版本: #{available_versions.join(', ')}"
        result[:messages] << "建议使用版本: #{DEFAULT_VERSION}"
      end

      result
    end

    # 从URL路径中提取版本号
    # @param path [String] URL路径
    # @return [String, nil] 版本号
    def extract_version_from_path(path)
      return nil unless path

      # 匹配 /api/v1/ 格式
      match = path.match(%r{/api/(v\d+)/})
      match ? match[1] : nil
    end

    # 获取版本变更日志
    # @param version [String] 版本号
    # @return [Array] 变更日志
    def changelog(version = DEFAULT_VERSION)
      changelog_data = {
        'v1' => [
          {
            date: '2025-10-15',
            version: 'v1.0.0',
            type: 'release',
            description: 'QQClub API v1.0 正式发布',
            changes: [
              '实现完整的用户认证和授权系统',
              '提供共读活动管理功能',
              '支持打卡和进度跟踪',
              '引入小红花激励机制',
              '添加评论和互动系统',
              '实现通知系统',
              '提供内容搜索和导出功能',
              '集成数据统计分析'
            ],
            breaking_changes: [],
            new_features: [
              'POST /api/v1/reading_events - 创建共读活动',
              'POST /api/v1/check_ins - 提交打卡',
              'POST /api/v1/flowers - 发送小红花',
              'GET /api/v1/notifications - 获取通知列表',
              'GET /api/v1/analytics/overview - 获取统计概览'
            ]
          }
        ]
      }

      changelog_data[version] || []
    end

    # 比较版本
    # @param version1 [String] 版本1
    # @param version2 [String] 版本2
    # @return [Integer] 比较结果 (-1, 0, 1)
    def compare_versions(version1, version2)
      v1_parts = version1.scan(/\d+/).map(&:to_i)
      v2_parts = version2.scan(/\d+/).map(&:to_i)

      max_length = [v1_parts.length, v2_parts.length].max

      max_length.times do |i|
        v1_part = v1_parts[i] || 0
        v2_part = v2_parts[i] || 0

        comparison = v1_part <=> v2_part
        return comparison unless comparison == 0
      end

      0
    end

    # 获取最新的稳定版本
    # @return [String] 最新版本
    def latest_stable_version
      SUPPORTED_VERSIONS.select { |v| version_info(v)[:status] == 'stable' }
                     .max { |a, b| compare_versions(a, b) }
    end
  end
end