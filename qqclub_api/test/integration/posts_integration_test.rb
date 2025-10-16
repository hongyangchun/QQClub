# frozen_string_literal: true

require "test_helper"

class PostsIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user(:user, nickname: "普通用户")
    @admin = create_test_user(:admin, nickname: "管理员")
    @other_user = create_test_user(:user, nickname: "其他用户")

    @user_headers = authenticate_user(@user)
    @admin_headers = authenticate_user(@admin)
    @other_user_headers = authenticate_user(@other_user)
  end

  # 完整的帖子生命周期测试
  test "should support complete post lifecycle" do
    # 1. 创建帖子
    post_params = {
      title: "我的第一篇读书心得",
      content: "《深度工作》这本书给我带来了很多启发。作者提出了在现代社会中，深度工作能力的重要性。我认为这本书对于想要提高工作效率的人来说非常有价值。",
      category: "reading",
      tags: ["读书", "深度工作", "效率"],
      images: ["https://example.com/book_cover.jpg"]
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers
    assert_response :created

    create_response = JSON.parse(response.body)
    post_id = create_response["post"]["id"]
    assert_equal post_params[:title], create_response["post"]["title"]
    assert_equal post_params[:category], create_response["post"]["category"]
    assert_equal post_params[:tags], create_response["post"]["tags"]

    # 2. 获取帖子详情
    get api_post_path(post_id), headers: @user_headers
    assert_response :success

    show_response = JSON.parse(response.body)
    assert_equal post_id, show_response["id"]
    assert_equal 0, show_response["likes_count"]
    assert_equal 0, show_response["comments_count"]
    assert_equal false, show_response["liked_by_current_user"]

    # 3. 更新帖子
    update_params = {
      content: "《深度工作》这本书给我带来了很多启发。作者提出了在现代社会中，深度工作能力的重要性。我认为这本书对于想要提高工作效率的人来说非常有价值。另外，书中提到的具体方法也很实用。",
      tags: ["读书", "深度工作", "效率", "方法论"]
    }

    put api_post_path(post_id), params: { post: update_params }, headers: @user_headers
    assert_response :success

    update_response = JSON.parse(response.body)
    assert_equal update_params[:content], update_response["post"]["content"]
    assert_equal update_params[:tags], update_response["post"]["tags"]

    # 4. 获取帖子列表，验证更新后的内容
    get api_posts_path, headers: @user_headers
    assert_response :success

    index_response = JSON.parse(response.body)
    updated_post = index_response.find { |p| p["id"] == post_id }
    assert_equal 4, updated_post["tags"].length

    # 5. 删除帖子
    delete api_post_path(post_id), headers: @user_headers
    assert_response :no_content

    # 6. 验证帖子已删除
    get api_post_path(post_id), headers: @user_headers
    assert_response :not_found
  end

  # 帖子社交功能集成测试
  test "should support post social features" do
    # 1. 用户A创建帖子
    post_params = {
      title: "推荐一本好书",
      content: "最近读了《原则》这本书，感触很深。作者达利欧分享了他的人生和工作原则，对我启发很大。特别是关于'极度透明'和'极度真实'的理念。",
      category: "reading",
      tags: ["读书", "原则", "达利欧"]
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers
    assert_response :created

    create_response = JSON.parse(response.body)
    post_id = create_response["post"]["id"]

    # 2. 用户B点赞帖子
    post "/api/posts/#{post_id}/like", headers: @other_user_headers
    assert_response :success

    # 3. 用户B评论帖子
    comment_params = { comment: { content: "感谢推荐！我也很喜欢这本书，特别是关于生活原则的部分。" } }
    post "/api/posts/#{post_id}/comments", params: comment_params, headers: @other_user_headers
    assert_response :created

    # 4. 用户A再次查看帖子，验证统计更新
    get api_post_path(post_id), headers: @user_headers
    assert_response :success

    show_response = JSON.parse(response.body)
    assert_equal 1, show_response["likes_count"]
    assert_equal 1, show_response["comments_count"]
    assert_equal false, show_response["liked_by_current_user"]  # 作者未点赞自己的帖子

    # 5. 用户B查看帖子，验证点赞状态
    get api_post_path(post_id), headers: @other_user_headers
    assert_response :success

    user_show_response = JSON.parse(response.body)
    assert_equal 1, user_show_response["likes_count"]
    assert_equal 1, user_show_response["comments_count"]
    assert_equal true, user_show_response["liked_by_current_user"]  # 用户B已点赞

    # 6. 验证用户B不能重复点赞
    post "/api/posts/#{post_id}/like", headers: @other_user_headers
    assert_response :unprocessable_entity  # 重复点赞应该失败
  end

  # 管理员功能集成测试
  test "should support admin management features" do
    # 1. 用户创建多个帖子
    posts = []
    3.times do |i|
      post_params = {
        title: "帖子 #{i + 1}",
        content: "这是第 #{i + 1} 个帖子的内容，长度满足系统要求。" * 5,
        category: i.even? ? "reading" : "activity"
      }

      post api_posts_path, params: { post: post_params }, headers: @user_headers
      assert_response :created

      create_response = JSON.parse(response.body)
      posts << create_response["post"]
    end

    # 2. 管理员置顶第一个帖子
    post pin_api_post_path(posts[0]["id"]), headers: @admin_headers
    assert_response :success

    # 3. 管理员隐藏第二个帖子
    post hide_api_post_path(posts[1]["id"]), headers: @admin_headers
    assert_response :success

    # 4. 普通用户查看帖子列表
    get api_posts_path, headers: @other_user_headers
    assert_response :success

    index_response = JSON.parse(response.body)
    assert_equal 2, index_response.length  # 被隐藏的帖子不可见
    assert_equal true, index_response[0]["pinned"]  # 置顶帖子在首位
    assert_equal false, index_response[1]["pinned"]

    # 5. 管理员查看所有帖子
    get api_posts_path, headers: @admin_headers
    assert_response :success

    admin_index_response = JSON.parse(response.body)
    assert_equal 3, admin_index_response.length  # 管理员可以看到所有帖子

    # 6. 管理员编辑被隐藏的帖子
    update_params = {
      title: "管理员编辑的帖子",
      content: "管理员编辑了帖子的内容，确保长度满足系统要求。" * 5
    }

    put api_post_path(posts[1]["id"]), params: { post: update_params }, headers: @admin_headers
    assert_response :success

    # 7. 管理员取消隐藏帖子
    post unhide_api_post_path(posts[1]["id"]), headers: @admin_headers
    assert_response :success

    # 8. 普通用户现在可以看到所有帖子
    get api_posts_path, headers: @other_user_headers
    assert_response :success

    final_index_response = JSON.parse(response.body)
    assert_equal 3, final_index_response.length
  end

  # 搜索和筛选集成测试
  test "should support search and filter functionality" do
    # 1. 创建不同类型的帖子
    posts_data = [
      {
        title: "《深度工作》读书笔记",
        content: "深度工作是一种专业技能，在当今的数字经济时代变得越来越有价值。",
        category: "reading",
        tags: ["读书", "深度工作", "效率"]
      },
      {
        title: "周末读书分享会活动",
        content: "本周六下午2点，我们将在图书馆举办读书分享会活动。",
        category: "activity",
        tags: ["活动", "分享", "读书会"]
      },
      {
        title: "推荐一本小说",
        content: "最近读了一本很好的小说，情节引人入胜，值得推荐。",
        category: "chat",
        tags: ["小说", "推荐", "休闲"]
      }
    ]

    created_posts = []
    posts_data.each do |post_data|
      post api_posts_path, params: { post: post_data }, headers: @user_headers
      assert_response :created
      created_posts << JSON.parse(response.body)["post"]
    end

    # 2. 按分类筛选
    get api_posts_path, params: { category: "reading" }, headers: @user_headers
    assert_response :success

    reading_posts = JSON.parse(response.body)
    assert_equal 1, reading_posts.length
    assert_equal "reading", reading_posts[0]["category"]

    # 3. 按关键词搜索
    get api_posts_path, params: { keyword: "读书" }, headers: @user_headers
    assert_response :success

    search_results = JSON.parse(response.body)
    assert_equal 2, search_results.length  # 包含"读书"的帖子

    # 4. 组合筛选
    get api_posts_path, params: { category: "reading", keyword: "深度" }, headers: @user_headers
    assert_response :success

    combined_results = JSON.parse(response.body)
    assert_equal 1, combined_results.length
    assert_equal "深度工作", combined_results[0]["title"]

    # 5. 搜索无结果
    get api_posts_path, params: { keyword: "不存在的关键词" }, headers: @user_headers
    assert_response :success

    empty_results = JSON.parse(response.body)
    assert_equal 0, empty_results.length
  end

  # 并发操作集成测试
  test "should handle concurrent operations correctly" do
    # 1. 创建帖子
    post_params = {
      title: "并发测试帖子",
      content: "这是一个用于测试并发操作的帖子，确保长度满足系统要求。" * 10
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers
    assert_response :created

    create_response = JSON.parse(response.body)
    post_id = create_response["post"]["id"]

    # 2. 模拟多个用户同时点赞
    threads = []
    users = [@other_user]

    users.each do |user|
      threads << Thread.new do
        user_headers = authenticate_user(user)
        post "/api/posts/#{post_id}/like", headers: user_headers
      end
    end

    threads.each(&:join)

    # 3. 验证点赞数
    get api_post_path(post_id), headers: @user_headers
    assert_response :success

    show_response = JSON.parse(response.body)
    assert_equal 1, show_response["likes_count"]

    # 4. 模拟并发评论
    comment_threads = []
    comment_contents = [
      "第一条评论内容",
      "第二条评论内容",
      "第三条评论内容"
    ]

    comment_contents.each do |content|
      comment_threads << Thread.new do
        comment_params = { comment: { content: content } }
        post "/api/posts/#{post_id}/comments", params: comment_params, headers: @other_user_headers
      end
    end

    comment_threads.each(&:join)

    # 5. 验证评论数
    get api_post_path(post_id), headers: @user_headers
    assert_response :success

    final_response = JSON.parse(response.body)
    assert_equal 3, final_response["comments_count"]
  end

  # 错误处理集成测试
  test "should handle errors gracefully" do
    # 1. 访问不存在的帖子
    get api_post_path(99999), headers: @user_headers
    assert_response :not_found

    error_response = JSON.parse(response.body)
    assert_equal "帖子不存在", error_response["error"]

    # 2. 尝试操作不存在的帖子
    post "/api/posts/99999/like", headers: @user_headers
    assert_response :not_found

    # 3. 无效的创建数据
    invalid_params = {
      title: "",
      content: "太短",
      category: "invalid"
    }

    post api_posts_path, params: { post: invalid_params }, headers: @user_headers
    assert_response :unprocessable_entity

    error_response = JSON.parse(response.body)
    assert error_response["errors"]
    assert_includes error_response["errors"], "Title can't be blank"
    assert_includes error_response["errors"], "Content is too short (minimum is 10 characters)"

    # 4. 未授权的操作
    valid_params = {
      title: "测试帖子",
      content: "这是一个测试帖子，长度足够。" * 10
    }

    post api_posts_path, params: { post: valid_params }
    assert_response :unauthorized

    # 5. 超长内容测试
    too_long_content = "a" * 6000
    long_params = {
      title: "超长内容测试",
      content: too_long_content
    }

    post api_posts_path, params: { post: long_params }, headers: @user_headers
    assert_response :unprocessable_entity

    error_response = JSON.parse(response.body)
    assert_includes error_response["errors"], "Content is too long (maximum is 5000 characters)"
  end

  # 性能集成测试
  test "should handle large amounts of data efficiently" do
    # 1. 批量创建帖子
    start_time = Time.current

    posts_count = 10
    created_posts = []

    posts_count.times do |i|
      post_params = {
        title: "批量创建的帖子 #{i + 1}",
        content: "这是第 #{i + 1} 个批量创建的帖子，包含足够的内容长度。" * 20,
        category: ["reading", "activity", "chat"].sample,
        tags: ["标签#{i + 1}", "测试"],
        images: ["https://example.com/image#{i + 1}.jpg"]
      }

      post api_posts_path, params: { post: post_params }, headers: @user_headers
      assert_response :created

      created_posts << JSON.parse(response.body)["post"]
    end

    creation_time = Time.current - start_time

    # 创建操作应该在合理时间内完成
    assert creation_time < 10.seconds
    assert_equal posts_count, created_posts.length

    # 2. 测试分页性能
    start_time = Time.current

    get api_posts_path, headers: @user_headers
    assert_response :success

    index_response = JSON.parse(response.body)
    assert_equal posts_count, index_response.length

    index_time = Time.current - start_time

    # 索引操作应该很快
    assert index_time < 2.seconds

    # 3. 测试搜索性能
    start_time = Time.current

    get api_posts_path, params: { keyword: "批量" }, headers: @user_headers
    assert_response :success

    search_response = JSON.parse(response.body)
    assert_equal posts_count, search_response.length

    search_time = Time.current - start_time

    # 搜索操作应该在合理时间内完成
    assert search_time < 3.seconds

    # 4. 测试带图片的帖子性能
    post_params = {
      title: "多图性能测试",
      content: "这是一个包含大量图片的帖子，用于测试性能。" * 20,
      images: Array.new(20) { |i| "https://example.com/perf_test#{i}.jpg" }
    }

    start_time = Time.current

    post api_posts_path, params: { post: post_params }, headers: @user_headers
    assert_response :created

    multi_image_time = Time.current - start_time

    # 多图帖子创建应该在合理时间内完成
    assert multi_image_time < 5.seconds
  end

  # 数据一致性集成测试
  test "should maintain data consistency across operations" do
    # 1. 创建帖子
    original_params = {
      title: "数据一致性测试",
      content: "这是一个测试数据一致性的帖子，包含足够的内容长度。" * 10,
      category: "reading",
      tags: ["测试", "一致性"]
    }

    post api_posts_path, params: { post: original_params }, headers: @user_headers
    assert_response :created

    create_response = JSON.parse(response.body)
    post_id = create_response["post"]["id"]

    # 2. 验证初始数据
    get api_post_path(post_id), headers: @user_headers
    assert_response :success

    show_response = JSON.parse(response.body)
    assert_equal original_params[:title], show_response["title"]
    assert_equal original_params[:content], show_response["content"]
    assert_equal original_params[:category], show_response["category"]
    assert_equal original_params[:tags], show_response["tags"]

    # 3. 执行部分更新
    partial_update = {
      title: "更新后的标题"
    }

    put api_post_path(post_id), params: { post: partial_update }, headers: @user_headers
    assert_response :success

    update_response = JSON.parse(response.body)
    assert_equal partial_update[:title], update_response["post"]["title"]
    assert_equal original_params[:content], update_response["post"]["content"]  # 其他字段应保持不变

    # 4. 验证数据库中的数据
    get api_post_path(post_id), headers: @user_headers
    assert_response :success

    final_response = JSON.parse(response.body)
    assert_equal partial_update[:title], final_response["title"]
    assert_equal original_params[:content], final_response["content"]
    assert_equal original_params[:category], final_response["category"]
    assert_equal original_params[:tags], final_response["tags"]

    # 5. 测试事务回滚
    invalid_update = {
      title: "x" * 150,  # 超过限制
      content: "有效内容" * 10
    }

    put api_post_path(post_id), params: { post: invalid_update }, headers: @user_headers
    assert_response :unprocessable_entity

    # 验证原始数据未被修改
    get api_post_path(post_id), headers: @user_headers
    assert_response :success

    rollback_response = JSON.parse(response.body)
    assert_equal partial_update[:title], rollback_response["title"]  # 应该是上次成功更新的值
  end
end