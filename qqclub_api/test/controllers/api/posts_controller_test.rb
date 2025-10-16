# frozen_string_literal: true

require "test_helper"

class Api::PostsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user(:user, nickname: "测试用户")
    @admin = create_test_user(:admin, nickname: "管理员")
    @other_user = create_test_user(:user, nickname: "其他用户")

    @user_headers = authenticate_user(@user)
    @admin_headers = authenticate_user(@admin)
    @other_user_headers = authenticate_user(@other_user)
  end

  # Index Tests
  test "should get posts as regular user" do
    visible_post = create_test_post(user: @user, pinned: false, hidden: false)
    hidden_post = create_test_post(user: @other_user, pinned: false, hidden: true)
    pinned_post = create_test_post(user: @other_user, pinned: true, hidden: false)

    get api_posts_path, headers: @user_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 2, json_response.length

    # Pinned post should come first
    assert_equal pinned_post.id, json_response[0]["id"]
    assert_equal true, json_response[0]["pinned"]

    # Regular post should come second
    assert_equal visible_post.id, json_response[1]["id"]
    assert_equal false, json_response[1]["pinned"]

    # Hidden post should not be visible to regular user
    post_ids = json_response.map { |p| p["id"] }
    assert_not_includes post_ids, hidden_post.id
  end

  test "should get all posts as admin including hidden ones" do
    visible_post = create_test_post(user: @user, pinned: false, hidden: false)
    hidden_post = create_test_post(user: @other_user, pinned: false, hidden: true)
    pinned_post = create_test_post(user: @other_user, pinned: true, hidden: false)

    get api_posts_path, headers: @admin_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 3, json_response.length

    post_ids = json_response.map { |p| p["id"] }
    assert_includes post_ids, visible_post.id
    assert_includes post_ids, hidden_post.id
    assert_includes post_ids, pinned_post.id
  end

  test "should include can_edit_current_user in posts index" do
    user_post = create_test_post(user: @user)
    other_post = create_test_post(user: @other_user)

    get api_posts_path, headers: @user_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    user_post_data = json_response.find { |p| p["id"] == user_post.id }
    other_post_data = json_response.find { |p| p["id"] == other_post.id }

    assert_equal true, user_post_data["can_edit_current_user"]
    assert_equal false, other_post_data["can_edit_current_user"]
  end

  test "should require authentication for posts index" do
    get api_posts_path
    assert_response :unauthorized
  end

  # Show Tests
  test "should show visible post to regular user" do
    post = create_test_post(user: @user, hidden: false)

    get api_post_path(post), headers: @user_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal post.id, json_response["id"]
    assert_equal post.title, json_response["title"]
    assert_equal post.content, json_response["content"]
  end

  test "should not show hidden post to regular user" do
    post = create_test_post(user: @user, hidden: true)

    get api_post_path(post), headers: @user_headers

    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_equal "帖子已被隐藏", json_response["error"]
  end

  test "should show hidden post to admin" do
    post = create_test_post(user: @user, hidden: true)

    get api_post_path(post), headers: @admin_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal post.id, json_response["id"]
    assert_equal true, json_response["hidden"]
  end

  test "should include can_edit_current_user in post show" do
    user_post = create_test_post(user: @user)

    get api_post_path(user_post), headers: @user_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal true, json_response["can_edit_current_user"]
  end

  test "should return 404 for non-existent post" do
    get api_post_path(99999), headers: @user_headers

    assert_response :not_found
  end

  test "should require authentication for post show" do
    post = create_test_post(user: @user)

    get api_post_path(post)
    assert_response :unauthorized
  end

  # Create Tests
  test "should create post with valid data" do
    post_params = {
      title: "测试帖子标题",
      content: "这是一个测试帖子内容，确保长度满足系统要求的至少10个字符。"
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers

    assert_response :created

    json_response = JSON.parse(response.body)
    assert_equal "帖子创建成功", json_response["message"]
    assert_equal post_params[:title], json_response["post"]["title"]
    assert_equal post_params[:content], json_response["post"]["content"]
    assert_equal @user.id, json_response["post"]["author_info"]["id"]
  end

  test "should return errors when creating post with invalid data" do
    post_params = {
      title: "",
      content: "太短"
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert json_response["errors"]
    assert_includes json_response["errors"], "Title can't be blank"
    assert_includes json_response["errors"], "Content is too short (minimum is 10 characters)"
  end

  test "should require authentication for post creation" do
    post_params = {
      title: "未授权帖子",
      content: "这是一个未授权创建的帖子内容，长度应该足够。"
    }

    post api_posts_path, params: { post: post_params }

    assert_response :unauthorized
  end

  # Update Tests
  test "should update own post" do
    post = create_test_post(user: @user, title: "原标题", content: "原内容，至少10个字符。")
    update_params = {
      title: "更新后的标题",
      content: "更新后的内容，确保长度满足系统要求。"
    }

    put api_post_path(post), params: { post: update_params }, headers: @user_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "帖子更新成功", json_response["message"]
    assert_equal update_params[:title], json_response["post"]["title"]
    assert_equal update_params[:content], json_response["post"]["content"]
  end

  test "admin should update other user's post" do
    post = create_test_post(user: @other_user, title: "原标题", content: "原内容，至少10个字符。")
    update_params = {
      title: "管理员更新的标题",
      content: "管理员更新的内容，确保长度足够。"
    }

    put api_post_path(post), params: { post: update_params }, headers: @admin_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal update_params[:title], json_response["post"]["title"]
  end

  test "should not update other user's post" do
    post = create_test_post(user: @other_user, title: "原标题", content: "原内容，至少10个字符。")
    update_params = {
      title: "尝试更新他人帖子",
      content: "尝试更新他人帖子的内容，长度足够。"
    }

    put api_post_path(post), params: { post: update_params }, headers: @user_headers

    assert_response :forbidden

    json_response = JSON.parse(response.body)
    assert_equal "无权限编辑此帖子", json_response["error"]
  end

  test "should return errors when updating with invalid data" do
    post = create_test_post(user: @user)
    update_params = {
      title: "",
      content: "太短"
    }

    put api_post_path(post), params: { post: update_params }, headers: @user_headers

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert json_response["errors"]
  end

  test "should require authentication for post update" do
    post = create_test_post(user: @user)
    update_params = {
      title: "未授权更新",
      content: "未授权更新的内容，长度足够。"
    }

    put api_post_path(post), params: { post: update_params }

    assert_response :unauthorized
  end

  # Delete Tests
  test "should delete own post" do
    post = create_test_post(user: @user)

    delete api_post_path(post), headers: @user_headers

    assert_response :no_content
    assert_not Post.exists?(post.id)
  end

  test "admin should delete other user's post" do
    post = create_test_post(user: @other_user)

    delete api_post_path(post), headers: @admin_headers

    assert_response :no_content
    assert_not Post.exists?(post.id)
  end

  test "should not delete other user's post" do
    post = create_test_post(user: @other_user)

    delete api_post_path(post), headers: @user_headers

    assert_response :forbidden

    json_response = JSON.parse(response.body)
    assert_equal "无权限删除此帖子", json_response["error"]
    assert Post.exists?(post.id)
  end

  test "should require authentication for post deletion" do
    post = create_test_post(user: @user)

    delete api_post_path(post)

    assert_response :unauthorized
  end

  # Pin Tests
  test "admin should pin post" do
    post = create_test_post(user: @user, pinned: false)

    post pin_api_post_path(post), headers: @admin_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "帖子已置顶", json_response["message"]
    assert_equal true, json_response["post"]["pinned"]

    post.reload
    assert post.pinned?
  end

  test "admin should unpin post" do
    post = create_test_post(user: @user, pinned: true)

    post unpin_api_post_path(post), headers: @admin_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "帖子已取消置顶", json_response["message"]
    assert_equal false, json_response["post"]["pinned"]

    post.reload
    assert_not post.pinned?
  end

  test "regular user should not pin post" do
    post = create_test_post(user: @user, pinned: false)

    post pin_api_post_path(post), headers: @user_headers

    assert_response :forbidden
  end

  test "regular user should not unpin post" do
    post = create_test_post(user: @user, pinned: true)

    post unpin_api_post_path(post), headers: @user_headers

    assert_response :forbidden
  end

  test "should require admin authentication for pin operations" do
    post = create_test_post(user: @user)

    post pin_api_post_path(post), headers: @other_user_headers
    assert_response :forbidden

    post unpin_api_post_path(post), headers: @other_user_headers
    assert_response :forbidden
  end

  # Hide Tests
  test "admin should hide post" do
    post = create_test_post(user: @user, hidden: false)

    post hide_api_post_path(post), headers: @admin_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "帖子已隐藏", json_response["message"]
    assert_equal true, json_response["post"]["hidden"]

    post.reload
    assert post.hidden?
  end

  test "admin should unhide post" do
    post = create_test_post(user: @user, hidden: true)

    post unhide_api_post_path(post), headers: @admin_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "帖子已显示", json_response["message"]
    assert_equal false, json_response["post"]["hidden"]

    post.reload
    assert_not post.hidden?
  end

  test "regular user should not hide post" do
    post = create_test_post(user: @user, hidden: false)

    post hide_api_post_path(post), headers: @user_headers

    assert_response :forbidden
  end

  test "regular user should not unhide post" do
    post = create_test_post(user: @user, hidden: true)

    post unhide_api_post_path(post), headers: @user_headers

    assert_response :forbidden
  end

  test "should require admin authentication for hide operations" do
    post = create_test_post(user: @user)

    post hide_api_post_path(post), headers: @other_user_headers
    assert_response :forbidden

    post unhide_api_post_path(post), headers: @other_user_headers
    assert_response :forbidden
  end

  # Edge Cases Tests
  test "should handle concurrent post updates" do
    post = create_test_post(user: @user, title: "原标题", content: "原内容，至少10个字符。")

    # Simulate concurrent updates
    original_updated_at = post.updated_at
    post.update!(title: "第一次更新")

    put api_post_path(post), params: {
      post: { title: "第二次更新", content: "第二次更新的内容，长度足够。" }
    }, headers: @user_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "第二次更新", json_response["post"]["title"]
  end

  test "should handle very long post content" do
    long_content = "a" * 5000
    post_params = {
      title: "长内容测试",
      content: long_content
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers

    assert_response :created

    json_response = JSON.parse(response.body)
    assert_equal long_content.length, json_response["post"]["content"].length
  end

  # Image Upload Integration Tests
  test "should create post with images" do
    post_params = {
      title: "带图片的帖子",
      content: "这是一个包含图片的帖子内容，确保长度满足系统要求的至少10个字符。",
      images: ["https://example.com/image1.jpg", "https://example.com/image2.png"]
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers

    assert_response :created

    json_response = JSON.parse(response.body)
    assert_equal post_params[:images], json_response["post"]["images"]
    assert_equal 2, json_response["post"]["images"].length
  end

  test "should update post with images" do
    post = create_test_post(user: @user, title: "原标题", content: "原内容，至少10个字符。")
    update_params = {
      title: "更新标题",
      content: "更新内容，确保长度满足系统要求。",
      images: ["https://example.com/new_image.jpg"]
    }

    put api_post_path(post), params: { post: update_params }, headers: @user_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal update_params[:images], json_response["post"]["images"]
    assert_equal 1, json_response["post"]["images"].length
  end

  test "should handle empty images array" do
    post_params = {
      title: "无图片帖子",
      content: "这是一个没有图片的帖子内容，确保长度满足系统要求的至少10个字符。",
      images: []
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers

    assert_response :created

    json_response = JSON.parse(response.body)
    assert_equal [], json_response["post"]["images"]
  end

  # Category Tests
  test "should create post with category" do
    post_params = {
      title: "分类测试帖子",
      content: "这是一个带有分类的帖子内容，确保长度满足系统要求的至少10个字符。",
      category: "reading"
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers

    assert_response :created

    json_response = JSON.parse(response.body)
    assert_equal "reading", json_response["post"]["category"]
  end

  test "should update post category" do
    post = create_test_post(user: @user, title: "原标题", content: "原内容，至少10个字符。", category: nil)
    update_params = {
      category: "activity"
    }

    put api_post_path(post), params: { post: update_params }, headers: @user_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "activity", json_response["post"]["category"]
  end

  # Tags Tests
  test "should create post with tags" do
    post_params = {
      title: "标签测试帖子",
      content: "这是一个包含标签的帖子内容，确保长度满足系统要求的至少10个字符。",
      tags: ["小说", "读书", "文学"]
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers

    assert_response :created

    json_response = JSON.parse(response.body)
    assert_equal post_params[:tags], json_response["post"]["tags"]
    assert_equal 3, json_response["post"]["tags"].length
  end

  test "should update post tags" do
    post = create_test_post(user: @user, title: "原标题", content: "原内容，至少10个字符。")
    update_params = {
      tags: ["科技", "创新"]
    }

    put api_post_path(post), params: { post: update_params }, headers: @user_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal update_params[:tags], json_response["post"]["tags"]
    assert_equal 2, json_response["post"]["tags"].length
  end

  # Like Count Tests
  test "should include likes count in post response" do
    post = create_test_post(user: @user, title: "测试帖子", content: "这是一个测试帖子，长度足够。")

    get api_post_path(post), headers: @user_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("likes_count")
    assert json_response["likes_count"].is_a?(Integer)
    assert_equal 0, json_response["likes_count"]
  end

  test "should include comments count in post response" do
    post = create_test_post(user: @user, title: "测试帖子", content: "这是一个测试帖子，长度足够。")

    get api_post_path(post), headers: @user_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("comments_count")
    assert json_response["comments_count"].is_a?(Integer)
    assert_equal 0, json_response["comments_count"]
  end

  # Like Status Tests
  test "should include liked_by_current_user in post response" do
    post = create_test_post(user: @user, title: "测试帖子", content: "这是一个测试帖子，长度足够。")

    get api_post_path(post), headers: @user_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("liked_by_current_user")
    assert_equal false, json_response["liked_by_current_user"]
  end

  # Views Count Tests
  test "should include views count in post response" do
    post = create_test_post(user: @user, title: "测试帖子", content: "这是一个测试帖子，长度足够。")

    get api_post_path(post), headers: @user_headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("views_count")
    assert json_response["views_count"].is_a?(Integer)
  end

  # Integration Tests with Comments
  test "should create post and then add comments" do
    # 1. 创建帖子
    post_params = {
      title: "集成测试帖子",
      content: "这是一个集成测试帖子，用于验证创建帖子后添加评论的功能，确保长度足够。"
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers
    assert_response :created

    create_response = JSON.parse(response.body)
    post_id = create_response["post"]["id"]

    # 2. 添加评论
    comment_params = { comment: { content: "这是第一条评论" } }
    post "/api/posts/#{post_id}/comments", params: comment_params, headers: @user_headers
    assert_response :created

    # 3. 验证评论数更新
    get api_post_path(post_id), headers: @user_headers
    assert_response :success

    show_response = JSON.parse(response.body)
    assert_equal 1, show_response["comments_count"]
  end

  # Integration Tests with Likes
  test "should create post and then like it" do
    # 1. 创建帖子
    post_params = {
      title: "点赞集成测试帖子",
      content: "这是一个点赞集成测试帖子，用于验证创建帖子后点赞的功能，确保长度足够。"
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers
    assert_response :created

    create_response = JSON.parse(response.body)
    post_id = create_response["post"]["id"]

    # 2. 点赞帖子
    post "/api/posts/#{post_id}/like", headers: @other_user_headers
    assert_response :success

    # 3. 验证点赞数更新
    get api_post_path(post_id), headers: @user_headers
    assert_response :success

    show_response = JSON.parse(response.body)
    assert_equal 1, show_response["likes_count"]
  end

  # Search and Filter Tests
  test "should filter posts by category" do
    reading_post = create_test_post(user: @user, title: "读书帖子", content: "读书内容", category: "reading")
    activity_post = create_test_post(user: @other_user, title: "活动帖子", content: "活动内容", category: "activity")

    get api_posts_path, params: { category: "reading" }, headers: @user_headers
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response.length
    assert_equal reading_post.id, json_response[0]["id"]
    assert_equal "reading", json_response[0]["category"]
  end

  test "should search posts by keyword" do
    search_post = create_test_post(user: @user, title: "搜索测试标题", content: "包含搜索关键词的内容")
    other_post = create_test_post(user: @other_user, title: "其他标题", content: "其他内容")

    get api_posts_path, params: { keyword: "搜索" }, headers: @user_headers
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response.length
    assert_equal search_post.id, json_response[0]["id"]
  end

  # Performance Tests
  test "should handle multiple image uploads efficiently" do
    post_params = {
      title: "多图测试帖子",
      content: "这是一个包含多张图片的帖子内容，确保长度足够。",
      images: Array.new(5) { |i| "https://example.com/image#{i}.jpg" }
    }

    start_time = Time.current

    post api_posts_path, params: { post: post_params }, headers: @user_headers
    assert_response :created

    end_time = Time.current

    # 应该在合理时间内完成
    assert (end_time - start_time) < 5.seconds

    json_response = JSON.parse(response.body)
    assert_equal 5, json_response["post"]["images"].length
  end

  # Edge Cases Tests
  test "should handle post with maximum allowed content length" do
    max_content = "a" * 5000
    post_params = {
      title: "最大长度测试",
      content: max_content
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers
    assert_response :created

    json_response = JSON.parse(response.body)
    assert_equal max_content, json_response["post"]["content"]
  end

  test "should handle post with minimum allowed content length" do
    min_content = "a" * 10
    post_params = {
      title: "最小长度测试",
      content: min_content
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers
    assert_response :created

    json_response = JSON.parse(response.body)
    assert_equal min_content, json_response["post"]["content"]
  end

  test "should handle post with special characters" do
    post_params = {
      title: "特殊字符测试!@#$%^&*()",
      content: "包含特殊字符的内容：!@#$%^&*()_+-={}[]|;:,.<>?"
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers
    assert_response :created

    json_response = JSON.parse(response.body)
    assert_equal post_params[:title], json_response["post"]["title"]
    assert_equal post_params[:content], json_response["post"]["content"]
  end

  test "should handle post with unicode content" do
    post_params = {
      title: "Unicode测试 📚",
      content: "包含Unicode的内容：中文、English、😊、🎉"
    }

    post api_posts_path, params: { post: post_params }, headers: @user_headers
    assert_response :created

    json_response = JSON.parse(response.body)
    assert_equal post_params[:title], json_response["post"]["title"]
    assert_equal post_params[:content], json_response["post"]["content"]
  end
end