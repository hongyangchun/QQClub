#!/usr/bin/env ruby

# 简单的测试脚本，检查认证行为
require_relative 'config/environment'

puts "=== 检查认证行为差异 ==="

# 1. 检查无认证创建活动
puts "\n1. 测试无认证创建活动:"
begin
  post_data = {
    title: "测试活动",
    book_name: "测试书籍"
  }

  # 模拟POST请求
  controller = Api::V1::ReadingEventsController.new
  controller.request = ActionDispatch::TestRequest.create(post_data)

  # 尝试调用create动作
  controller.create
  puts "状态码: #{controller.response.status}"
  puts "响应体: #{controller.response.body[0..200]}..."
rescue => e
  puts "异常: #{e.class.name}: #{e.message}"
  puts "堆栈: #{e.backtrace.first(3).join("\n  ")}"
end

# 2. 检查无效token
puts "\n2. 测试无效token:"
begin
  token = "invalid_token"
  decoded = User.decode_jwt_token(token)
  puts "Token解码结果: #{decoded}"
rescue => e
  puts "Token解码异常: #{e.class.name}: #{e.message}"
end

# 3. 检查用户权限
puts "\n3. 检查用户权限:"
begin
  user = User.first
  if user
    puts "用户角色: #{user.role} (#{user.role_as_string})"
    puts "是否管理员: #{user.admin?}"
    puts "JWT Token: #{user.generate_jwt_token[0..50]}..."
  else
    puts "没有找到用户"
  end
rescue => e
  puts "权限检查异常: #{e.class.name}: #{e.message}"
end

puts "\n=== 检查完成 ==="