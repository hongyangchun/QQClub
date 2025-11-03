# frozen_string_literal: true

require 'benchmark'
require 'test_helper'

class PostsPerformanceTest < ActionDispatch::IntegrationTest
  def setup
    # 创建测试数据
    @user = User.create!(nickname: 'Test User', wx_openid: 'test_openid_perf', role: 0)
    @admin_user = User.create!(nickname: 'Admin User', wx_openid: 'admin_openid_perf', role: 2)

    # 创建大量测试帖子
    @posts = create_test_posts(100)
  end

  def teardown
    # 清理测试数据
    Post.delete_all
    User.where(wx_openid: ['test_openid_perf', 'admin_openid_perf']).delete_all
  end

  # 测试原始PostsController性能
  test "原始PostsController#index 性能测试" do
    get "/api/posts", headers: auth_headers(@user)

    puts "\n=== 原始PostsController#index 性能测试 ==="
    puts "响应状态: #{response.status}"
    puts "响应大小: #{response.body.size} bytes"

    # 测试多次请求的平均性能
    times = []
    10.times do
      time = Benchmark.realtime do
        get "/api/posts", headers: auth_headers(@user)
      end
      times << time
    end

    avg_time = (times.sum / times.length) * 1000
    puts "平均响应时间: #{avg_time.round(2)}ms"
    puts "最大响应时间: #{(times.max * 1000).round(2)}ms"
    puts "最小响应时间: #{(times.min * 1000).round(2)}ms"
  end

  # 测试优化后的PerformancePostsController性能
  test "PerformancePostsController#index 性能测试" do
    get "/api/v1/performance_posts", headers: auth_headers(@user)

    puts "\n=== PerformancePostsController#index 性能测试 ==="
    puts "响应状态: #{response.status}"
    puts "响应大小: #{response.body.size} bytes"

    # 测试多次请求的平均性能
    times = []
    10.times do
      time = Benchmark.realtime do
        get "/api/v1/performance_posts", headers: auth_headers(@user)
      end
      times << time
    end

    avg_time = (times.sum / times.length) * 1000
    puts "平均响应时间: #{avg_time.round(2)}ms"
    puts "最大响应时间: #{(times.max * 1000).round(2)}ms"
    puts "最小响应时间: #{(times.min * 1000).round(2)}ms"

    # 检查性能信息
    json_response = JSON.parse(response.body)
    if json_response['performance']
      puts "缓存命中: #{json_response['performance']['cache_hit']}"
      puts "查询时间: #{json_response['performance']['query_time_ms']}ms"
    end
  end

  # 测试缓存性能
  test "PerformancePostsController 缓存性能测试" do
    # 第一次请求（缓存未命中）
    time1 = Benchmark.realtime do
      get "/api/v1/performance_posts", headers: auth_headers(@user)
    end

    # 第二次请求（缓存命中）
    time2 = Benchmark.realtime do
      get "/api/v1/performance_posts", headers: auth_headers(@user)
    end

    puts "\n=== 缓存性能测试 ==="
    puts "首次请求时间: #{(time1 * 1000).round(2)}ms"
    puts "缓存命中时间: #{(time2 * 1000).round(2)}ms"
    puts "性能提升: #{((time1 - time2) / time1 * 100).round(2)}%"

    response_json = JSON.parse(response.body)
    if response_json['cached']
      puts "缓存状态: #{response_json['cached']}"
      puts "缓存命中: #{response_json['performance']['cache_hit']}"
    end
  end

  # 测试分页性能
  test "分页性能对比测试" do
    puts "\n=== 分页性能测试 ==="

    # 测试不同页面的性能
    pages = [1, 5, 10]
    pages.each do |page|
      time = Benchmark.realtime do
        get "/api/v1/performance_posts?page=#{page}", headers: auth_headers(@user)
      end

      json_response = JSON.parse(response.body)
      pagination = json_response['pagination']

      puts "第#{page}页: #{(time * 1000).round(2)}ms - #{pagination['total_count']}条记录"
    end
  end

  # 测试cursor分页性能
  test "Cursor分页性能测试" do
    puts "\n=== Cursor分页性能测试 ==="

    # 第一页
    time1 = Benchmark.realtime do
      get "/api/v1/performance_posts?per_page=20", headers: auth_headers(@user)
    end
    response1 = JSON.parse(response.body)
    first_cursor = response1['pagination']['next_cursor']

    puts "首页: #{(time1 * 1000).round(2)}ms"

    # 使用cursor翻页
    if first_cursor
      time2 = Benchmark.realtime do
        get "/api/v1/performance_posts?cursor=#{first_cursor}&per_page=20", headers: auth_headers(@user)
      end

      puts "Cursor翻页: #{(time2 * 1000).round(2)}ms"
    end
  end

  # 测试不同数据量的性能
  test "数据量性能测试" do
    puts "\n=== 数据量性能测试 ==="

    # 测试不同的per_page参数
    per_pages = [10, 20, 50]
    per_pages.each do |per_page|
      time = Benchmark.realtime do
        get "/api/v1/performance_posts?per_page=#{per_page}", headers: auth_headers(@user)
      end

      puts "每页#{per_page}条: #{(time * 1000).round(2)}ms"
    end
  end

  # 测试权限预加载性能
  test "权限预加载性能测试" do
    puts "\n=== 权限预加载性能测试 ==="

    # 测试带权限信息的请求
    time = Benchmark.realtime do
      get "/api/v1/performance_posts?include_permissions=true", headers: auth_headers(@user)
    end

    puts "权限预加载: #{(time * 1000).round(2)}ms"

    response_json = JSON.parse(response.body)
    if response_json['posts'].any?
      first_post = response_json['posts'].first
      puts "包含权限信息: #{first_post.key?('interactions')}"
    end
  end

  # 测试统计接口性能
  test "统计接口性能测试" do
    puts "\n=== 统计接口性能测试 ==="

    time = Benchmark.realtime do
      get "/api/v1/performance_posts/stats", headers: auth_headers(@user)
    end

    puts "统计接口: #{(time * 1000).round(2)}ms"

    response_json = JSON.parse(response.body)
    if response_json['stats']
      puts "缓存状态: #{response_json['cached']}"
      puts "统计项数量: #{response_json['stats'].keys.length}"
    end
  end

  # 测试并发性能
  test "并发性能测试" do
    puts "\n=== 并发性能测试 ==="
    puts "模拟10个并发请求..."

    require 'thread'

    threads = []
    times = []
    mutex = Mutex.new

    10.times do
      threads << Thread.new do
        time = Benchmark.realtime do
          get "/api/v1/performance_posts", headers: auth_headers(@user)
        end
        mutex.synchronize { times << time }
      end
    end

    threads.each(&:join)

    avg_time = (times.sum / times.length) * 1000
    max_time = times.max * 1000
    min_time = times.min * 1000

    puts "并发平均时间: #{avg_time.round(2)}ms"
    puts "并发最大时间: #{max_time.round(2)}ms"
    puts "并发最小时间: #{min_time.round(2)}ms"
  end

  # 测试数据库查询优化效果
  test "数据库查询优化测试" do
    puts "\n=== 数据库查询优化测试 ==="

    # 使用SQL查询分析器
    query_count = 0
    ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
      query_count += 1
    end

    time = Benchmark.realtime do
      get "/api/v1/performance_posts", headers: auth_headers(@user)
    end

    puts "优化后查询次数: #{query_count}"
    puts "响应时间: #{(time * 1000).round(2)}ms"
    puts "平均查询时间: #{(time / query_count * 1000).round(2)}ms"

    # 重置查询计数器
    query_count = 0

    # 测试原始控制器
    time_original = Benchmark.realtime do
      get "/api/posts", headers: auth_headers(@user)
    end

    puts "原始查询次数: #{query_count}"
    puts "原始响应时间: #{(time_original * 1000).round(2)}ms"
    puts "查询次数减少: #{((query_count - 5).to_f / query_count * 100).round(2)}%" if query_count > 5
  end

  private

  def auth_headers(user)
    token = user.generate_jwt_token
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end

  def create_test_posts(count)
    posts = []
    categories = %w[reading activity chat help]

    count.times do |i|
      post = Post.create!(
        title: "Test Post #{i + 1}",
        content: "This is test content for post #{i + 1}. " * 10,
        user: @user,
        category: categories.sample,
        created_at: (count - i).hours.ago  # 确保时间分布
      )
      posts << post

      # 创建一些评论和点赞
      create_test_comments(post, rand(0..5))
      create_test_likes(post, rand(0..10))
    end

    posts
  end

  def create_test_comments(post, count)
    count.times do |i|
      Comment.create!(
        content: "Test comment #{i + 1} for post #{post.id}",
        user: @user,
        post: post,
        created_at: (count - i).minutes.ago
      )
    end
  end

  def create_test_likes(post, count)
    count.times do |i|
      # 使用不同的用户ID模拟点赞
      Like.create!(
        user: @user,
        target: post,
        created_at: (count - i).minutes.ago
      )
    end
  end
end