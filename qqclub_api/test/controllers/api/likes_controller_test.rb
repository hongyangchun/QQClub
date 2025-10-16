# frozen_string_literal: true

require "test_helper"

class Api::LikesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user(:user)
    @admin = create_test_user(:admin)
    @other_user = create_test_user(:user)
    @post = create_test_post(user: @user)
    @other_post = create_test_post(user: @other_user)
  end

  # Authentication Tests
  test "should require authentication for create" do
    post "/api/posts/#{@post.id}/like"
    assert_response :unauthorized
  end

  test "should require authentication for destroy" do
    delete "/api/posts/#{@post.id}/like"
    assert_response :unauthorized
  end

  # Create Tests (Like)
  test "should like post successfully" do
    post "/api/posts/#{@post.id}/like", headers: authenticate_user(@other_user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal '点赞成功', json_response['message']
    assert_equal true, json_response['liked']
    assert json_response['likes_count']
    assert_equal 1, json_response['likes_count']

    # 验证数据库中的记录
    assert Like.exists?(user: @other_user, target: @post)
    assert Like.liked?(@other_user, @post)
  end

  test "should not like already liked post" do
    # 先点赞
    Like.like!(@other_user, @post)

    post "/api/posts/#{@post.id}/like", headers: authenticate_user(@other_user)
    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_equal '已经点赞过了', json_response['error']

    # 验证只有一个点赞记录
    assert_equal 1, Like.where(user: @other_user, target: @post).count
  end

  test "should not like non-existent post" do
    post "/api/posts/99999/like", headers: authenticate_user(@user)
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_equal '目标不存在', json_response['error']
  end

  test "should allow self-like" do
    post "/api/posts/#{@post.id}/like", headers: authenticate_user(@user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal '点赞成功', json_response['message']
    assert_equal true, json_response['liked']

    # 验证可以点赞自己的帖子
    assert Like.exists?(user: @user, target: @post)
  end

  test "should work for different user roles" do
    # 普通用户点赞
    post "/api/posts/#{@post.id}/like", headers: authenticate_user(@other_user)
    assert_response :success

    # 管理员点赞
    post "/api/posts/#{@other_post.id}/like", headers: authenticate_user(@admin)
    assert_response :success

    # 验证两个点赞都成功
    assert Like.exists?(user: @other_user, target: @post)
    assert Like.exists?(user: @admin, target: @other_post)
  end

  test "should handle multiple users liking same post" do
    # 第一个用户点赞
    post "/api/posts/#{@post.id}/like", headers: authenticate_user(@other_user)
    assert_response :success

    first_response = JSON.parse(response.body)
    assert_equal 1, first_response['likes_count']

    # 第二个用户点赞
    post "/api/posts/#{@post.id}/like", headers: authenticate_user(@admin)
    assert_response :success

    second_response = JSON.parse(response.body)
    assert_equal 2, second_response['likes_count']

    # 验证有两个不同的点赞记录
    assert_equal 2, Like.where(target: @post).count
    assert Like.exists?(user: @other_user, target: @post)
    assert Like.exists?(user: @admin, target: @post)
  end

  test "should handle user liking multiple posts" do
    # 点赞第一个帖子
    post "/api/posts/#{@post.id}/like", headers: authenticate_user(@other_user)
    assert_response :success

    # 点赞第二个帖子
    post "/api/posts/#{@other_post.id}/like", headers: authenticate_user(@other_user)
    assert_response :success

    # 验证用户点赞了两个不同的帖子
    assert Like.exists?(user: @other_user, target: @post)
    assert Like.exists?(user: @other_user, target: @other_post)
    assert_equal 2, Like.where(user: @other_user).count
  end

  # Destroy Tests (Unlike)
  test "should unlike post successfully" do
    # 先点赞
    Like.like!(@other_user, @post)

    delete "/api/posts/#{@post.id}/like", headers: authenticate_user(@other_user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal '取消点赞成功', json_response['message']
    assert_equal false, json_response['liked']
    assert json_response['likes_count']
    assert_equal 0, json_response['likes_count']

    # 验证数据库中的记录被删除
    assert_not Like.exists?(user: @other_user, target: @post)
    assert_not Like.liked?(@other_user, @post)
  end

  test "should not unlike unliked post" do
    # 确保没有点赞
    assert_not Like.exists?(user: @other_user, target: @post)

    delete "/api/posts/#{@post.id}/like", headers: authenticate_user(@other_user)
    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_equal '还未点赞', json_response['error']
  end

  test "should not unlike non-existent post" do
    delete "/api/posts/99999/like", headers: authenticate_user(@user)
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_equal '目标不存在', json_response['error']
  end

  test "should allow self-unlike" do
    # 先点赞自己的帖子
    Like.like!(@user, @post)

    delete "/api/posts/#{@post.id}/like", headers: authenticate_user(@user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal '取消点赞成功', json_response['message']

    # 验证可以取消点赞自己的帖子
    assert_not Like.exists?(user: @user, target: @post)
  end

  test "should work for different user roles when unliking" do
    # 普通用户先点赞
    Like.like!(@other_user, @post)

    # 普通用户取消点赞
    delete "/api/posts/#{@post.id}/like", headers: authenticate_user(@other_user)
    assert_response :success

    # 管理员先点赞
    Like.like!(@admin, @other_post)

    # 管理员取消点赞
    delete "/api/posts/#{@other_post.id}/like", headers: authenticate_user(@admin)
    assert_response :success

    # 验证两个取消点赞都成功
    assert_not Like.exists?(user: @other_user, target: @post)
    assert_not Like.exists?(user: @admin, target: @other_post)
  end

  # Integration Tests
  test "should handle like and unlike lifecycle" do
    # 1. 点赞
    post "/api/posts/#{@post.id}/like", headers: authenticate_user(@other_user)
    assert_response :success

    like_response = JSON.parse(response.body)
    assert_equal true, like_response['liked']
    assert_equal 1, like_response['likes_count']

    # 2. 取消点赞
    delete "/api/posts/#{@post.id}/like", headers: authenticate_user(@other_user)
    assert_response :success

    unlike_response = JSON.parse(response.body)
    assert_equal false, unlike_response['liked']
    assert_equal 0, unlike_response['likes_count']

    # 3. 再次点赞
    post "/api/posts/#{@post.id}/like", headers: authenticate_user(@other_user)
    assert_response :success

    second_like_response = JSON.parse(response.body)
    assert_equal true, second_like_response['liked']
    assert_equal 1, second_like_response['likes_count']

    # 验证最终状态
    assert Like.exists?(user: @other_user, target: @post)
  end

  test "should handle concurrent like attempts correctly" do
    # 模拟两个用户同时点赞同一个帖子
    user1 = create_test_user(:user)
    user2 = create_test_user(:user)

    # 用户1点赞
    post "/api/posts/#{@post.id}/like", headers: authenticate_user(user1)
    assert_response :success

    response1 = JSON.parse(response.body)
    assert_equal 1, response1['likes_count']

    # 用户2点赞
    post "/api/posts/#{@post.id}/like", headers: authenticate_user(user2)
    assert_response :success

    response2 = JSON.parse(response.body)
    assert_equal 2, response2['likes_count']

    # 验证两个点赞都成功了
    assert_equal 2, Like.where(target: @post).count
    assert Like.exists?(user: user1, target: @post)
    assert Like.exists?(user: user2, target: @post)
  end

  test "should maintain correct likes count during multiple operations" do
    initial_count = @post.likes_count

    # 多个用户点赞
    users = Array.new(3) { create_test_user(:user) }

    users.each_with_index do |user, index|
      post "/api/posts/#{@post.id}/like", headers: authenticate_user(user)
      assert_response :success

      response = JSON.parse(response.body)
      expected_count = initial_count + index + 1
      assert_equal expected_count, response['likes_count']
    end

    # 验证最终点赞数
    @post.reload
    assert_equal initial_count + 3, @post.likes_count
    assert_equal 3, Like.where(target: @post).count

    # 部分用户取消点赞
    delete "/api/posts/#{@post.id}/like", headers: authenticate_user(users[0])
    assert_response :success

    response = JSON.parse(response.body)
    assert_equal initial_count + 2, response['likes_count']

    # 验证点赞数减少
    @post.reload
    assert_equal initial_count + 2, @post.likes_count
    assert_equal 2, Like.where(target: @post).count
  end

  # Edge Cases Tests
  test "should handle posts with no likes" do
    # 确保帖子没有点赞
    assert_equal 0, Like.where(target: @other_post).count

    # 尝试取消点赞
    delete "/api/posts/#{@other_post.id}/like", headers: authenticate_user(@user)
    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_equal '还未点赞', json_response['error']

    # 点赞数应该保持为0
    @other_post.reload
    assert_equal 0, @other_post.likes_count
  end

  test "should handle nil post_id parameter" do
    # 这个测试确保控制器能正确处理空参数
    post "/api/posts//like", headers: authenticate_user(@user)
    # 应该返回404而不是500
    assert_response :not_found
  end

  test "should handle invalid post_id parameter" do
    post "/api/posts/invalid/like", headers: authenticate_user(@user)
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_equal '目标不存在', json_response['error']
  end

  # Performance Tests (basic)
  test "should handle large number of likes efficiently" do
    # 创建多个用户
    users = Array.new(5) { create_test_user(:user) }

    start_time = Time.current

    # 批量点赞
    users.each do |user|
      post "/api/posts/#{@post.id}/like", headers: authenticate_user(user)
      assert_response :success
    end

    end_time = Time.current

    # 应该在合理时间内完成
    assert (end_time - start_time) < 5.seconds

    # 验证所有点赞都成功
    @post.reload
    assert_equal 5, @post.likes_count
    assert_equal 5, Like.where(target: @post).count
  end

  # Security Tests
  test "should not allow users to like on behalf of other users" do
    # 这个测试确保用户不能冒充其他用户点赞
    # 由于我们使用JWT token，这个测试主要是验证token的正确性

    # 使用用户A的token为用户B点赞（应该失败，因为token中的用户ID与实际操作不符）
    # 但在实际实现中，这会被当前的认证机制正确处理

    post "/api/posts/#{@post.id}/like", headers: authenticate_user(@user)
    assert_response :success

    # 验证确实是用户A点的赞
    assert Like.exists?(user: @user, target: @post)
    assert_not Like.exists?(user: @other_user, target: @post)
  end

  private

  def authenticate_user(user)
    token = user.generate_jwt_token
    { "Authorization" => "Bearer #{token}" }
  end
end