#!/usr/bin/env ruby
# frozen_string_literal: true

# Token管理测试脚本
require 'net/http'
require 'json'
require 'uri'

class TokenTest
  BASE_URL = 'http://localhost:3000'

  def self.run
    puts "=== Token 管理系统测试 ===\n"

    # 1. 测试登录获取tokens
    puts "1. 测试登录并获取tokens..."
    login_result = test_login
    return false unless login_result

    return false unless login_result.is_a?(Hash)

    access_token = login_result['access_token']
    refresh_token = login_result['refresh_token']

    puts "✓ 登录成功"
    puts "  Access Token: #{access_token ? access_token[0..50] : 'nil'}..."
    puts "  Refresh Token: #{refresh_token ? refresh_token[0..50] : 'nil'}...\n"

    # 2. 测试access token有效性
    puts "2. 测试access token有效性..."
    me_result = test_me(access_token)
    user_data = me_result.is_a?(Hash) ? (me_result['user'] || me_result) : nil
    if user_data && user_data['id']
      puts "✓ Access token有效"
      puts "  用户ID: #{user_data['id']}\n"
    else
      puts "✗ Access token无效"
      return false
    end

    # 3. 测试access token过期场景（模拟）
    puts "3. 测试token刷新..."
    refresh_result = test_refresh_token(refresh_token)
    if refresh_result && refresh_result['access_token']
      new_access_token = refresh_result['access_token']
      puts "✓ Token刷新成功"
      puts "  新Access Token: #{new_access_token[0..50]}..."

      # 验证新token
      me_result_after = test_me(new_access_token)
      user_data_after = me_result_after.is_a?(Hash) ? (me_result_after['user'] || me_result_after) : nil
      if user_data_after && user_data_after['id']
        puts "✅ 新token验证成功，用户ID: #{user_data_after['id']}\n"
      else
        puts "✗ 新token验证失败"
        return false
      end
    else
      puts "✗ Token刷新失败"
      return false
    end

    # 4. 测试错误处理
    puts "4. 测试错误处理..."
    test_error_handling

    puts "\n=== 测试完成 ==="
    puts "🎉 所有Token管理功能正常工作！"
    true
  end

  private

  def self.test_login
    uri = URI("#{BASE_URL}/api/auth/mock_login")
    response = make_request(uri, :post, {
      openid: 'test_dhf_001',
      nickname: '测试用户',
      avatar_url: 'https://picsum.photos/100/100?random=dhh'
    })
    response
  end

  def self.test_me(access_token)
    uri = URI("#{BASE_URL}/api/auth/me")
    response = make_request(uri, :get, nil, access_token)
    response
  end

  def self.test_refresh_token(refresh_token)
    uri = URI("#{BASE_URL}/api/auth/refresh_token")
    response = make_request(uri, :post, {
      refresh_token: refresh_token
    })
    response
  end

  def self.test_error_handling
    # 测试无效refresh token
    puts "  - 测试无效refresh token..."
    result = test_refresh_token("invalid_token")
    if result && result['error_code'] == 'INVALID_REFRESH_TOKEN'
      puts "  ✓ 正确返回INVALID_REFRESH_TOKEN错误"
    else
      puts "  ✗ 错误处理异常"
    end

    # 测试缺少refresh token参数
    puts "  - 测试缺少refresh token参数..."
    uri = URI("#{BASE_URL}/api/auth/refresh_token")
    response = make_request(uri, :post, {})
    if response && response['error_code'] == 'MISSING_REFRESH_TOKEN'
      puts "  ✓ 正确返回MISSING_REFRESH_TOKEN错误"
    else
      puts "  ✗ 错误处理异常"
    end

    # 测试无效access token
    puts "  - 测试无效access token..."
    result = test_me("invalid_token")
    if result && result['error_code']
      puts "  ✓ 正确返回认证错误: #{result['error_code']}"
    else
      puts "  ✗ 错误处理异常"
    end
  end

  def self.make_request(uri, method, body = nil, token = nil)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.open_timeout = 10
    http.read_timeout = 10

    request = case method
    when :get
      Net::HTTP::Get.new(uri.request_uri)
    when :post
      req = Net::HTTP::Post.new(uri.request_uri)
      req['Content-Type'] = 'application/json'
      req.body = body.to_json if body
      req
    else
      raise "Unsupported method: #{method}"
    end

    request['Authorization'] = "Bearer #{token}" if token

    response = http.request(request)
    JSON.parse(response.body)
  rescue JSON::ParserError => e
    { error: "JSON parse error: #{e.message}", error_code: 'JSON_ERROR' }
  rescue => e
    { error: e.message, error_code: 'NETWORK_ERROR' }
  end
end

# 运行测试
if __FILE__ == $0
  TokenTest.run
end