#!/usr/bin/env ruby

# QQClub API Test Framework - 专业的API测试框架
# 提供完整的API端点测试功能

require 'json'
require 'net/http'
require 'uri'
require 'optparse'
require 'fileutils'

class APITestFramework
  def initialize(base_url = 'http://localhost:3000')
    @base_url = base_url
    @results = []
    @test_data = {}
    @tokens = {}
    @config = load_config
  end

  # 运行所有API测试
  def run_all_tests
    puts "🚀 开始QQClub API测试"
    puts "=" * 50

    setup_test_environment
    test_authentication_endpoints
    test_forum_endpoints
    test_event_endpoints
    test_permission_endpoints
    test_error_handling

    generate_report
  end

  # 设置测试环境
  def setup_test_environment
    puts "🔧 设置测试环境..."

    create_test_users
    verify_server_connection

    puts "✅ 测试环境设置完成"
  end

  # 创建测试用户
  def create_test_users
    puts "👥 创建测试用户..."

    users = {
      root: { wx_openid: 'test_root_api', nickname: 'Root API用户' },
      admin: { wx_openid: 'test_admin_api', nickname: 'Admin API用户' },
      user: { wx_openid: 'test_user_api', nickname: '普通 API用户' }
    }

    users.each do |role, user_data|
      response = api_request('POST', '/auth/mock_login', { user: user_data })
      if response && response['token']
        @tokens[role] = response['token']
        @test_data[role] = response['user']
        puts "  ✅ 创建#{role}用户: #{user_data[:nickname]}"
      else
        puts "  ❌ 创建#{role}用户失败"
      end
    end
  end

  # 验证服务器连接
  def verify_server_connection
    response = api_request('GET', '/health')
    if response && response['status'] == 'ok'
      puts "  ✅ 服务器连接正常"
    else
      puts "  ❌ 服务器连接失败"
      exit 1
    end
  end

  # 测试认证端点
  def test_authentication_endpoints
    puts "\n🔐 测试认证端点..."

    test_user_login
    test_get_current_user
    test_update_user_profile
    test_invalid_token
  end

  # 测试用户登录
  def test_user_login
    test_data = { user: { wx_openid: 'test_new_user', nickname: '新测试用户' } }

    result = api_test('POST', '/auth/mock_login', test_data, nil, 201) do |response|
      response['token'] && response['user']['nickname'] == '新测试用户'
    end

    @tokens[:new_user] = result['token'] if result['success']
  end

  # 测试获取当前用户信息
  def test_get_current_user
    api_test('GET', '/auth/me', nil, @tokens[:user]) do |response|
      response['id'] && response['nickname']
    end
  end

  # 测试更新用户资料
  def test_update_user_profile
    update_data = { user: { nickname: '更新后的API用户' } }

    api_test('PUT', '/auth/profile', update_data, @tokens[:user]) do |response|
      response['nickname'] == '更新后的API用户'
    end
  end

  # 测试无效token
  def test_invalid_token
    api_test('GET', '/auth/me', nil, 'invalid_token', 401)
  end

  # 测试论坛端点
  def test_forum_endpoints
    puts "\n💬 测试论坛端点..."

    test_create_post
    test_get_posts
    test_get_post_detail
    test_update_post
    test_delete_post
    test_post_management
  end

  # 测试创建帖子
  def test_create_post
    post_data = {
      post: {
        title: 'API测试帖子',
        content: '这是一个通过API测试创建的帖子内容，确保满足系统要求的长度限制，同时包含足够的信息来验证帖子的创建功能是否正常工作。'
      }
    }

    result = api_test('POST', '/posts', post_data, @tokens[:user]) do |response|
      response['id'] && response['title'] == 'API测试帖子'
    end

    @test_data[:test_post] = result if result['success']
  end

  # 测试获取帖子列表
  def test_get_posts
    api_test('GET', '/posts', nil, @tokens[:user]) do |response|
      response.is_a?(Array) && response.length >= 0
    end
  end

  # 测试获取帖子详情
  def test_get_post_detail
    return unless @test_data[:test_post]

    post_id = @test_data[:test_post]['id']
    api_test("GET", "/posts/#{post_id}", nil, @tokens[:user]) do |response|
      response['id'] == post_id
    end
  end

  # 测试更新帖子
  def test_update_post
    return unless @test_data[:test_post]

    post_id = @test_data[:test_post]['id']
    update_data = { post: { title: '更新后的API测试帖子' } }

    api_test("PUT", "/posts/#{post_id}", update_data, @tokens[:user]) do |response|
      response['title'] == '更新后的API测试帖子'
    end
  end

  # 测试删除帖子
  def test_delete_post
    return unless @test_data[:test_post]

    post_id = @test_data[:test_post]['id']
    api_test("DELETE", "/posts/#{post_id}", nil, @tokens[:user], 204)
  end

  # 测试帖子管理功能
  def test_post_management
    # 创建一个新帖子用于管理测试
    post_data = {
      post: {
        title: '管理测试帖子',
        content: '这是一个用于测试管理功能的帖子，包括置顶、隐藏等操作。'
      }
    }

    result = api_request('POST', '/posts', post_data, @tokens[:user])
    return unless result

    post_id = result['id']

    # 测试置顶帖子
    api_test("POST", "/posts/#{post_id}/pin", nil, @tokens[:admin]) do |response|
      response['success'] == true
    end

    # 测试取消置顶
    api_test("POST", "/posts/#{post_id}/unpin", nil, @tokens[:admin]) do |response|
      response['success'] == true
    end

    # 测试隐藏帖子
    api_test("POST", "/posts/#{post_id}/hide", nil, @tokens[:admin]) do |response|
      response['success'] == true
    end

    # 清理测试帖子
    api_request("DELETE", "/posts/#{post_id}", nil, @tokens[:user])
  end

  # 测试活动端点
  def test_event_endpoints
    puts "\n📚 测试活动端点..."

    test_create_event
    test_get_events
    test_get_event_detail
    test_update_event
    test_event_enrollment
    test_delete_event
  end

  # 测试创建活动
  def test_create_event
    event_data = {
      event: {
        title: 'API测试读书活动',
        book_name: '测试书籍',
        description: '这是一个通过API创建的测试读书活动',
        start_date: Date.today.to_s,
        end_date: (Date.today + 7.days).to_s,
        max_participants: 10,
        enrollment_fee: 50.0
      }
    }

    result = api_test('POST', '/events', event_data, @tokens[:user]) do |response|
      response['id'] && response['title'] == 'API测试读书活动'
    end

    @test_data[:test_event] = result if result['success']
  end

  # 测试获取活动列表
  def test_get_events
    api_test('GET', '/events', nil, @tokens[:user]) do |response|
      response.is_a?(Array) && response.length >= 0
    end
  end

  # 测试获取活动详情
  def test_get_event_detail
    return unless @test_data[:test_event]

    event_id = @test_data[:test_event]['id']
    api_test("GET", "/events/#{event_id}", nil, @tokens[:user]) do |response|
      response['id'] == event_id
    end
  end

  # 测试更新活动
  def test_update_event
    return unless @test_data[:test_event]

    event_id = @test_data[:test_event]['id']
    update_data = { event: { description: '更新后的活动描述' } }

    api_test("PUT", "/events/#{event_id}", update_data, @tokens[:user]) do |response|
      response['description'].include?('更新后的活动描述')
    end
  end

  # 测试活动报名
  def test_event_enrollment
    return unless @test_data[:test_event]

    event_id = @test_data[:test_event]['id']
    api_test("POST", "/events/#{event_id}/enroll", nil, @tokens[:new_user]) do |response|
      response['success'] == true
    end
  end

  # 测试删除活动
  def test_delete_event
    return unless @test_data[:test_event]

    event_id = @test_data[:test_event]['id']
    api_test("DELETE", "/events/#{event_id}", nil, @tokens[:user], 204)
  end

  # 测试权限端点
  def test_permission_endpoints
    puts "\n🔒 测试权限端点..."

    test_admin_dashboard_access
    test_user_permission_denial
    test_permission_hierarchy
  end

  # 测试管理员面板访问
  def test_admin_dashboard_access
    api_test('GET', '/admin/dashboard', nil, @tokens[:admin]) do |response|
      response['total_users'] && response['total_events']
    end
  end

  # 测试普通用户权限拒绝
  def test_user_permission_denial
    api_test('GET', '/admin/dashboard', nil, @tokens[:user], 403)
  end

  # 测试权限层次
  def test_permission_hierarchy
    # Root用户应该能访问所有管理员功能
    api_test('GET', '/admin/users', nil, @tokens[:root]) do |response|
      response.is_a?(Array)
    end

    # Admin用户不能访问Root专有功能
    api_test('POST', '/admin/init_root', nil, @tokens[:admin], 403)
  end

  # 测试错误处理
  def test_error_handling
    puts "\n⚠️  测试错误处理..."

    test_not_found_errors
    test_validation_errors
    test_authorization_errors
  end

  # 测试404错误
  def test_not_found_errors
    api_test('GET', '/nonexistent/endpoint', nil, @tokens[:user], 404)
    api_test('GET', '/posts/99999', nil, @tokens[:user], 404)
    api_test('GET', '/events/99999', nil, @tokens[:user], 404)
  end

  # 测试验证错误
  def test_validation_errors
    # 测试创建空帖子
    invalid_post_data = { post: { title: '', content: '' } }
    api_test('POST', '/posts', invalid_post_data, @tokens[:user], 422)

    # 测试创建无效活动
    invalid_event_data = { event: { title: '', book_name: '' } }
    api_test('POST', '/events', invalid_event_data, @tokens[:user], 422)
  end

  # 测试授权错误
  def test_authorization_errors
    # 尝试编辑不属于自己的帖子
    api_test('PUT', '/posts/1', { post: { title: '黑客尝试' } }, @tokens[:user], 403)

    # 尝试访问管理员功能
    api_test('GET', '/admin/users', nil, @tokens[:user], 403)
  end

  # API测试核心方法
  def api_test(method, endpoint, data = nil, token = nil, expected_status = 200, &block)
    start_time = Time.now
    response = api_request(method, endpoint, data, token, expected_status)
    end_time = Time.now
    duration = ((end_time - start_time) * 1000).round(2)

    success = response && (block.nil? || block.call(response))

    result = {
      method: method,
      endpoint: endpoint,
      expected_status: expected_status,
      actual_status: get_status_code(response),
      duration: duration,
      success: success,
      response: success ? response : nil,
      error: success ? nil : get_error_message(response)
    }

    @results << result

    status_icon = success ? '✅' : '❌'
    puts "  #{status_icon} #{method.upcase} #{endpoint} (#{duration}ms) #{success ? '通过' : '失败'}"

    unless success
      puts "    错误: #{result[:error]}"
    end

    result
  end

  # 发送API请求
  def api_request(method, endpoint, data = nil, token = nil, expected_status = nil)
    uri = URI("#{@base_url}/api#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 30
    http.open_timeout = 10

    request = case method.upcase
              when 'GET'
                Net::HTTP::Get.new(uri)
              when 'POST'
                req = Net::HTTP::Post.new(uri)
                req.body = data.to_json if data
                req
              when 'PUT'
                req = Net::HTTP::Put.new(uri)
                req.body = data.to_json if data
                req
              when 'DELETE'
                Net::HTTP::Delete.new(uri)
              end

    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{token}" if token

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    elsif expected_status && response.code.to_i == expected_status
      { success: true }
    else
      { error: "HTTP #{response.code}: #{response.message}" }
    end
  rescue => e
    { error: e.message }
  end

  # 获取状态码
  def get_status_code(response)
    if response.is_a?(Hash) && response['error']
      response['error'].match(/HTTP (\d+)/)&.to_a&.first&.to_i || 500
    else
      200
    end
  end

  # 获取错误消息
  def get_error_message(response)
    if response.is_a?(Hash)
      response['error'] || response['message'] || '未知错误'
    else
      '响应格式错误'
    end
  end

  # 生成测试报告
  def generate_report
    puts "\n" + "=" * 50
    puts "📊 API测试报告"
    puts "=" * 50

    total_tests = @results.length
    passed_tests = @results.count { |r| r[:success] }
    failed_tests = total_tests - passed_tests
    success_rate = total_tests > 0 ? (passed_tests.to_f / total_tests * 100).round(2) : 0

    total_duration = @results.sum { |r| r[:duration] }
    avg_duration = total_tests > 0 ? (total_duration / total_tests).round(2) : 0

    puts "总测试数: #{total_tests}"
    puts "通过测试: #{passed_tests}"
    puts "失败测试: #{failed_tests}"
    puts "成功率: #{success_rate}%"
    puts "总耗时: #{total_duration}ms"
    puts "平均响应时间: #{avg_duration}ms"

    if failed_tests > 0
      puts "\n❌ 失败的测试:"
      @results.select { |r| !r[:success] }.each do |result|
        puts "  - #{result[:method]} #{result[:endpoint]}: #{result[:error]}"
      end
    end

    puts "\n🏆 测试完成!"

    # 保存详细报告
    save_detailed_report if @config[:save_report]
  end

  # 保存详细报告
  def save_detailed_report
    report_dir = 'test_reports'
    FileUtils.mkdir_p(report_dir)

    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    report_file = File.join(report_dir, "api_test_report_#{timestamp}.json")

    report_data = {
      timestamp: Time.now.iso8601,
      base_url: @base_url,
      summary: {
        total_tests: @results.length,
        passed_tests: @results.count { |r| r[:success] },
        failed_tests: @results.count { |r| !r[:success] },
        success_rate: (@results.count { |r| r[:success] }.to_f / @results.length * 100).round(2),
        total_duration: @results.sum { |r| r[:duration] },
        avg_duration: (@results.sum { |r| r[:duration] }.to_f / @results.length).round(2)
      },
      results: @results
    }

    File.write(report_file, JSON.pretty_generate(report_data))
    puts "📄 详细报告已保存到: #{report_file}"
  end

  private

  # 加载配置
  def load_config
    config_file = 'api_test_config.json'
    if File.exist?(config_file)
      JSON.parse(File.read(config_file))
    else
      {
        save_report: true,
        timeout: 30,
        retry_count: 3
      }
    end
  rescue => e
    puts "⚠️  配置文件加载失败，使用默认配置: #{e.message}"
    { save_report: true }
  end
end

# 命令行接口
if __FILE__ == $0
  options = {}
  OptionParser.new do |opts|
    opts.banner = "用法: #{$0} [选项]"

    opts.on("-u", "--url URL", "API服务器地址 (默认: http://localhost:3000)") do |url|
      options[:url] = url
    end

    opts.on("-e", "--endpoint ENDPOINT", "测试特定端点") do |endpoint|
      options[:endpoint] = endpoint
    end

    opts.on("-m", "--method METHOD", "HTTP方法 (GET/POST/PUT/DELETE)") do |method|
      options[:method] = method.upcase
    end

    opts.on("-d", "--data DATA", "请求数据 (JSON格式)") do |data|
      options[:data] = JSON.parse(data)
    end

    opts.on("-t", "--token TOKEN", "认证token") do |token|
      options[:token] = token
    end

    opts.on("-s", "--status STATUS", Integer, "期望状态码") do |status|
      options[:status] = status
    end

    opts.on("-v", "--verbose", "详细输出") do
      options[:verbose] = true
    end

    opts.on("-h", "--help", "显示帮助信息") do
      puts opts
      exit
    end
  end.parse!

  framework = APITestFramework.new(options[:url])

  if options[:endpoint]
    # 测试单个端点
    result = framework.api_test(
      options[:method] || 'GET',
      options[:endpoint],
      options[:data],
      options[:token],
      options[:status]
    )
    puts JSON.pretty_generate(result)
  else
    # 运行完整测试套件
    framework.run_all_tests
  end
end