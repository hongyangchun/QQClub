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
end