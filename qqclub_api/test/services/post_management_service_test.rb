# frozen_string_literal: true

require "test_helper"

class PostManagementServiceTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user(:user)
    @admin = create_test_user(:admin)
    @post = create_test_post(user: @user, title: "测试帖子", content: "这是一个测试帖子内容，确保长度满足系统要求。")
  end

  # 创建帖子测试
  test "should create post successfully with valid data" do
    params = {
      title: "新帖子标题",
      content: "这是一个新帖子内容，确保长度满足系统要求的至少10个字符。"
    }

    service = PostManagementService.new(post: nil, user: @user, action: :create, post_params: params)
    result = service.call

    assert result.success?
    assert_equal "帖子创建成功", result.result[:message]
    # PostManagementService now returns string keys for API compatibility
    assert_equal params[:title], result.result[:post]["title"]
    assert_equal params[:content], result.result[:post]["content"]
    assert_equal @user.id, result.result[:post]["user_id"]
  end

  test "should fail post creation when user is nil" do
    service = PostManagementService.new(post: nil, user: nil, action: :create, post_params: {})
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "用户不能为空"
  end

  test "should fail post creation with invalid data" do
    params = {
      title: "",  # 空标题
      content: "太短"  # 内容太短
    }

    service = PostManagementService.new(post: nil, user: @user, action: :create, post_params: params)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "Title can't be blank"
    assert_includes result.error_messages, "Content is too short (minimum is 10 characters)"
  end

  test "should fail post creation with title too long" do
    params = {
      title: "a" * 101,  # 超过100字符限制
      content: "这是一个有效的内容，长度足够。"
    }

    service = PostManagementService.new(post: nil, user: @user, action: :create, post_params: params)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "Title is too long (maximum is 100 characters)"
  end

  # 更新帖子测试
  test "should update own post successfully" do
    params = {
      title: "更新后的标题",
      content: "更新后的内容，确保长度满足系统要求。"
    }

    service = PostManagementService.new(post: @post, user: @user, action: :update, post_params: params)
    result = service.call

    assert result.success?
    assert_equal "帖子更新成功", result.result[:message]
    assert_equal params[:title], result.result[:post]["title"]
    assert_equal params[:content], result.result[:post]["content"]
  end

  test "should update post as admin" do
    params = {
      title: "管理员更新标题",
      content: "管理员更新内容，确保长度足够。"
    }

    service = PostManagementService.new(post: @post, user: @admin, action: :update, post_params: params)
    result = service.call

    assert result.success?
    assert_equal params[:title], result.result[:post]["title"]
  end

  test "should fail update when user has no permission" do
    other_user = create_test_user(:user, nickname: "其他用户")
    params = { title: "尝试更新" }

    service = PostManagementService.new(post: @post, user: other_user, action: :update, post_params: params)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "无权限编辑此帖子"
  end

  test "should fail update when post is nil" do
    service = PostManagementService.new(post: nil, user: @user, action: :update, post_params: {})
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "帖子不能为空"
  end

  # 删除帖子测试
  test "should delete own post successfully" do
    service = PostManagementService.new(post: @post, user: @user, action: :delete)
    result = service.call

    assert result.success?
    assert_equal "帖子删除成功", result.result[:message]
    assert_not Post.exists?(@post.id)
  end

  test "should delete post as admin" do
    service = PostManagementService.new(post: @post, user: @admin, action: :delete)
    result = service.call

    assert result.success?
    assert_not Post.exists?(@post.id)
  end

  test "should fail delete when user has no permission" do
    other_user = create_test_user(:user)

    service = PostManagementService.new(post: @post, user: other_user, action: :delete)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "无权限删除此帖子"
    assert Post.exists?(@post.id)
  end

  # 置顶帖子测试
  test "should pin post as admin" do
    service = PostManagementService.new(post: @post, user: @admin, action: :pin)
    result = service.call

    assert result.success?
    assert_equal "帖子已置顶", result.result[:message]
    assert @post.reload.pinned?
  end

  test "should fail pin when user has no permission" do
    service = PostManagementService.new(post: @post, user: @user, action: :pin)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "无权限置顶此帖子"
    assert_not @post.reload.pinned?
  end

  # 取消置顶测试
  test "should unpin post as admin" do
    @post.update!(pinned: true)

    service = PostManagementService.new(post: @post, user: @admin, action: :unpin)
    result = service.call

    assert result.success?
    assert_equal "帖子已取消置顶", result.result[:message]
    assert_not @post.reload.pinned?
  end

  # 隐藏帖子测试
  test "should hide post as admin" do
    service = PostManagementService.new(post: @post, user: @admin, action: :hide)
    result = service.call

    assert result.success?
    assert_equal "帖子已隐藏", result.result[:message]
    assert @post.reload.hidden?
  end

  test "should unhide post as admin" do
    @post.update!(hidden: true)

    service = PostManagementService.new(post: @post, user: @admin, action: :unhide)
    result = service.call

    assert result.success?
    assert_equal "帖子已显示", result.result[:message]
    assert_not @post.reload.hidden?
  end

  test "should fail hide when user has no permission" do
    service = PostManagementService.new(post: @post, user: @user, action: :hide)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "无权限隐藏此帖子"
    assert_not @post.reload.hidden?
  end

  # 类方法测试
  test "should create post using class method" do
    params = {
      title: "类方法测试",
      content: "这是一个使用类方法创建的帖子，确保长度足够。"
    }

    result = PostManagementService.create_post!(@user, params)

    assert result.success?
    assert_equal "帖子创建成功", result.result[:message]
    assert_equal params[:title], result.result[:post]["title"]
  end

  test "should update post using class method" do
    params = { title: "类方法更新" }

    result = PostManagementService.update_post!(@post, @user, params)

    assert result.success?
    assert_equal "帖子更新成功", result.result[:message]
    assert_equal params[:title], result.result[:post]["title"]
  end

  test "should delete post using class method" do
    result = PostManagementService.delete_post!(@post, @user)

    assert result.success?
    assert_equal "帖子删除成功", result.result[:message]
    assert_not Post.exists?(@post.id)
  end

  test "should pin post using class method" do
    result = PostManagementService.pin_post!(@post, @admin)

    assert result.success?
    assert_equal "帖子已置顶", result.result[:message]
    assert @post.reload.pinned?
  end

  # 边界条件测试
  test "should handle unsupported action" do
    service = PostManagementService.new(post: @post, user: @user, action: :unsupported)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "不支持的操作: unsupported"
  end

  test "should handle post with maximum title length" do
    params = {
      title: "a" * 100,  # 正好100字符
      content: "这是一个有效的内容。"
    }

    service = PostManagementService.new(post: nil, user: @user, action: :create, post_params: params)
    result = service.call

    assert result.success?
    assert_equal 100, result.result[:post]["title"].length
  end

  test "should handle post with maximum content length" do
    params = {
      title: "标题",
      content: "a" * 5000  # 正好5000字符
    }

    service = PostManagementService.new(post: nil, user: @user, action: :create, post_params: params)
    result = service.call

    assert result.success?
    assert_equal 5000, result.result[:post]["content"].length
  end

  test "should handle post with minimum content length" do
    params = {
      title: "标题",
      content: "a" * 10  # 正好10字符
    }

    service = PostManagementService.new(post: nil, user: @user, action: :create, post_params: params)
    result = service.call

    assert result.success?
    assert_equal 10, result.result[:post]["content"].length
  end

  
  # 权限测试 - Root用户
  test "should allow root user to perform all actions" do
    root_user = create_test_user(:root)

    # 测试root用户更新帖子
    update_service = PostManagementService.new(post: @post, user: root_user, action: :update, post_params: { title: "Root更新" })
    update_result = update_service.call
    assert update_result.success?

    # 测试root用户删除帖子
    delete_service = PostManagementService.new(post: @post, user: root_user, action: :delete)
    delete_result = delete_service.call
    assert delete_result.success?
  end

  # 并发测试
  test "should handle concurrent updates correctly" do
    # 模拟并发更新场景
    original_title = @post.title

    service1 = PostManagementService.new(post: @post, user: @user, action: :update, post_params: { title: "并发更新1" })
    service2 = PostManagementService.new(post: @post, user: @user, action: :update, post_params: { title: "并发更新2" })

    result1 = service1.call
    result2 = service2.call

    # 至少有一个应该成功
    assert result1.success? || result2.success?
  end
end