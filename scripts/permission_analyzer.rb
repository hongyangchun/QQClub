#!/usr/bin/env ruby

# QQClub Permission Analyzer - 权限系统深度分析工具
# 这个Ruby脚本提供更深入的权限系统分析和诊断

require 'json'
require 'yaml'
require 'optparse'

class PermissionAnalyzer
  def initialize
    @project_root = File.dirname(__FILE__) + '/..'
    @api_root = File.join(@project_root, 'qqclub_api')
    @issues = []
    @warnings = []
    @suggestions = []
  end

  # 分析权限架构
  def analyze_architecture
    puts "🔍 分析权限架构..."

    check_user_model
    check_permission_concerns
    check_controller_permissions
    check_route_protection

    puts "✅ 权限架构分析完成"
  end

  # 检查用户模型
  def check_user_model
    user_model_path = File.join(@api_root, 'app/models/user.rb')

    unless File.exist?(user_model_path)
      @issues << "User模型文件不存在: #{user_model_path}"
      return
    end

    content = File.read(user_model_path)

    # 检查角色枚举
    unless content.include?('enum :role')
      @issues << "User模型缺少角色枚举定义"
    end

    # 检查关键权限方法
    required_methods = %w[any_admin? root? can_manage_event_content? can_approve_events?]
    required_methods.each do |method|
      unless content.include?(method)
        @issues << "User模型缺少权限方法: #{method}"
      end
    end

    # 检查角色值
    roles = %w[user admin root]
    roles.each do |role|
      unless content.include?("#{role}?")
        @warnings << "User模型可能缺少角色检查方法: #{role}?"
      end
    end
  end

  # 检查权限相关concerns
  def check_permission_concerns
    concerns_dir = File.join(@api_root, 'app/controllers/concerns')

    # 检查AdminAuthorizable
    admin_auth_path = File.join(concerns_dir, 'admin_authorizable.rb')
    unless File.exist?(admin_auth_path)
      @issues << "AdminAuthorizable concern不存在"
      return
    end

    content = File.read(admin_auth_path)

    # 检查关键方法
    required_methods = %w[authenticate_admin! authenticate_root!]
    required_methods.each do |method|
      unless content.include?(method)
        @issues << "AdminAuthorizable缺少方法: #{method}"
      end
    end
  end

  # 检查控制器权限
  def check_controller_permissions
    controllers_dir = File.join(@api_root, 'app/controllers')

    # 检查AdminController
    admin_controller_path = File.join(controllers_dir, 'admin_controller.rb')
    if File.exist?(admin_controller_path)
      content = File.read(admin_controller_path)

      unless content.include?('before_action :authenticate_admin!')
        @issues << "AdminController缺少权限验证"
      end
    else
      @issues << "AdminController不存在"
    end

    # 检查API控制器的认证
    api_controllers = Dir.glob(File.join(controllers_dir, 'api', '*_controller.rb'))
    api_controllers.each do |controller_path|
      content = File.read(controller_path)
      controller_name = File.basename(controller_path, '.rb')

      # 跳过认证控制器
      next if controller_name == 'auth_controller'

      unless content.include?('before_action :authenticate_user!')
        @warnings << "#{controller_name}可能缺少用户认证"
      end
    end
  end

  # 检查路由保护
  def check_route_protection
    routes_path = File.join(@api_root, 'config/routes.rb')

    unless File.exist?(routes_path)
      @issues << "路由文件不存在"
      return
    end

    content = File.read(routes_path)

    # 检查管理路由命名空间
    unless content.include?('namespace :admin')
      @warnings << "建议使用admin命名空间保护管理路由"
    end

    # 检查API路由
    unless content.include?('namespace :api')
      @issues << "缺少API命名空间"
    end
  end

  # 分析权限测试覆盖
  def analyze_test_coverage
    puts "🧪 分析权限测试覆盖..."

    check_model_tests
    check_controller_tests
    check_integration_tests

    puts "✅ 测试覆盖分析完成"
  end

  # 检查模型测试
  def check_model_tests
    test_dir = File.join(@api_root, 'test/models')

    if Dir.exist?(test_dir)
      user_test_path = File.join(test_dir, 'user_test.rb')
      if File.exist?(user_test_path)
        content = File.read(user_test_path)

        # 检查权限相关测试
        permission_tests = %w[admin root can_manage_event_content]
        permission_tests.each do |test|
          unless content.include?(test)
            @warnings << "User测试缺少权限测试: #{test}"
          end
        end
      else
        @warnings << "User模型测试文件不存在"
      end
    else
      @warnings << "模型测试目录不存在"
    end
  end

  # 检查控制器测试
  def check_controller_tests
    test_dir = File.join(@api_root, 'test/controllers')

    return unless Dir.exist?(test_dir)

    admin_test_path = File.join(test_dir, 'admin_controller_test.rb')
    if File.exist?(admin_test_path)
      content = File.read(admin_test_path)

      unless content.include?('authenticate_admin')
        @warnings << "AdminController测试缺少权限验证测试"
      end
    else
      @warnings << "AdminController测试文件不存在"
    end
  end

  # 检查集成测试
  def check_integration_tests
    test_dir = File.join(@api_root, 'test/integration')

    if Dir.exist?(test_dir)
      permission_tests = Dir.glob(File.join(test_dir, '*permission*'))
      if permission_tests.empty?
        @suggestions << "建议创建权限集成测试"
      end
    else
      @suggestions << "建议创建集成测试目录和权限测试"
    end
  end

  # 分析数据库权限相关
  def analyze_database_permissions
    puts "🗄️ 分析数据库权限相关..."

    check_migrations
    check_indexes

    puts "✅ 数据库权限分析完成"
  end

  # 检查迁移文件
  def check_migrations
    migrations_dir = File.join(@api_root, 'db/migrate')

    return unless Dir.exist?(migrations_dir)

    # 查找用户表迁移
    user_migrations = Dir.glob(File.join(migrations_dir, '*create_users.rb'))
    if user_migrations.empty?
      @issues << "找不到用户表创建迁移"
    else
      user_migration = File.read(user_migrations.first)

      unless user_migration.include?('role')
        @issues << "用户表缺少role字段"
      end

      unless user_migration.include?('index')
        @warnings << "用户表可能缺少必要索引"
      end
    end
  end

  # 检查索引
  def check_indexes
    schema_path = File.join(@api_root, 'db/schema.rb')

    if File.exist?(schema_path)
      content = File.read(schema_path)

      # 检查用户表索引
      unless content.include?('add_index "users", "wx_openid"')
        @issues << "用户表缺少wx_openid唯一索引"
      end

      unless content.include?('add_index "users", "role"')
        @warnings << "用户表可能缺少role字段索引"
      end
    end
  end

  # 生成权限矩阵
  def generate_permission_matrix
    puts "📊 生成权限矩阵..."

    matrix = {
      "Root" => {
        "用户管理" => true,
        "系统配置" => true,
        "活动审批" => true,
        "论坛管理" => true,
        "活动管理" => true,
        "领读内容" => true,
        "小红花评选" => true
      },
      "Admin" => {
        "用户管理" => "limited",
        "系统配置" => false,
        "活动审批" => true,
        "论坛管理" => true,
        "活动管理" => true,
        "领读内容" => true,
        "小红花评选" => true
      },
      "Group Leader" => {
        "用户管理" => false,
        "系统配置" => false,
        "活动审批" => false,
        "论坛管理" => false,
        "活动管理" => "own_events",
        "领读内容" => true,
        "小红花评选" => true
      },
      "Daily Leader" => {
        "用户管理" => false,
        "系统配置" => false,
        "活动审批" => false,
        "论坛管理" => false,
        "活动管理" => false,
        "领读内容" => "time_window",
        "小红花评选" => "time_window"
      },
      "Forum User" => {
        "用户管理" => false,
        "系统配置" => false,
        "活动审批" => false,
        "论坛管理" => false,
        "活动管理" => false,
        "领读内容" => false,
        "小红花评选" => false
      },
      "Participant" => {
        "用户管理" => false,
        "系统配置" => false,
        "活动审批" => false,
        "论坛管理" => false,
        "活动管理" => false,
        "领读内容" => false,
        "小红花评选" => false
      }
    }

    # 输出权限矩阵
    puts "\n权限矩阵:"
    puts "角色\\功能      |用户管理|系统配置|活动审批|论坛管理|活动管理|领读内容|小红花评选"
    puts "-" * 70

    matrix.each do |role, permissions|
      printf "%-13s |" % role
      permissions.each do |permission, value|
        case value
        when true
          printf "  ✅   |"
        when false
          printf "  ❌   |"
        when "limited"
          printf "  ⚠️   |"
        when "own_events"
          printf "  🏷️   |"
        when "time_window"
          printf "  ⏰   |"
        else
          printf "  ❓   |"
        end
      end
      puts
    end

    puts "\n图例: ✅=完全权限 ❌=无权限 ⚠️=有限权限 🏷️=仅自己活动 ⏰=时间窗口权限 ❓=未知"

    puts "✅ 权限矩阵生成完成"
  end

  # 生成改进建议
  def generate_recommendations
    puts "\n💡 改进建议:"

    if @issues.any?
      puts "\n🚨 必须修复的问题:"
      @issues.each_with_index do |issue, index|
        puts "#{index + 1}. #{issue}"
      end
    end

    if @warnings.any?
      puts "\n⚠️ 建议关注的警告:"
      @warnings.each_with_index do |warning, index|
        puts "#{index + 1}. #{warning}"
      end
    end

    if @suggestions.any?
      puts "\n💡 改进建议:"
      @suggestions.each_with_index do |suggestion, index|
        puts "#{index + 1}. #{suggestion}"
      end
    end

    # 通用建议
    puts "\n📋 通用建议:"
    puts "1. 定期运行权限检查工具"
    puts "2. 保持权限测试的高覆盖率"
    puts "3. 在代码审查中关注权限变更"
    puts "4. 记录权限变更的审计日志"
    puts "5. 定期进行权限安全评估"
  end

  # 生成完整报告
  def generate_report(output_file = nil)
    report = {
      timestamp: Time.now.iso8601,
      summary: {
        issues_count: @issues.length,
        warnings_count: @warnings.length,
        suggestions_count: @suggestions.length
      },
      issues: @issues,
      warnings: @warnings,
      suggestions: @suggestions
    }

    if output_file
      File.write(output_file, JSON.pretty_generate(report))
      puts "\n📄 详细报告已保存到: #{output_file}"
    end

    report
  end

  # 运行完整分析
  def run_analysis(options = {})
    puts "🔒 QQClub 权限系统深度分析"
    puts "=" * 50
    puts

    analyze_architecture
    analyze_test_coverage
    analyze_database_permissions
    generate_permission_matrix
    generate_recommendations

    if options[:output]
      generate_report(options[:output])
    end

    # 返回分析结果
    {
      success: @issues.empty?,
      issues: @issues,
      warnings: @warnings,
      suggestions: @suggestions
    }
  end
end

# 命令行接口
if __FILE__ == $0
  options = {}
  OptionParser.new do |opts|
    opts.banner = "用法: #{$0} [选项]"

    opts.on("-o", "--output FILE", "输出详细报告到文件") do |file|
      options[:output] = file
    end

    opts.on("-h", "--help", "显示帮助信息") do
      puts opts
      exit
    end
  end.parse!

  analyzer = PermissionAnalyzer.new
  result = analyzer.run_analysis(options)

  exit(result[:success] ? 0 : 1)
end