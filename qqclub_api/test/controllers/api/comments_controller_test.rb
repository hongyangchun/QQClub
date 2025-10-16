# frozen_string_literal: true

require "test_helper"

class Api::CommentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user(:user)
    @admin = create_test_user(:admin)
    @other_user = create_test_user(:user)
    @post = create_test_post(user: @user)
    @comment = Comment.create!(
      content: "Test comment",
      user: @user,
      post: @post,
      commentable: @post
    )
  end

  # Authentication Tests
  test "should require authentication for index" do
    get "/api/posts/#{@post.id}/comments"
    assert_response :unauthorized
  end

  test "should require authentication for create" do
    post "/api/posts/#{@post.id}/comments", params: { comment: { content: "New comment" } }
    assert_response :unauthorized
  end

  test "should require authentication for update" do
    put "/api/comments/#{@comment.id}", params: { comment: { content: "Updated comment" } }
    assert_response :unauthorized
  end

  test "should require authentication for destroy" do
    delete "/api/comments/#{@comment.id}"
    assert_response :unauthorized
  end

  # Index Tests
  test "should get comments for post" do
    get "/api/posts/#{@post.id}/comments", headers: authenticate_user(@user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal true, json_response['success']
    assert json_response['data'].is_a?(Array)
    assert_equal 1, json_response['data'].length
    assert_equal '获取评论列表成功', json_response['message']

    comment_data = json_response['data'].first
    assert_equal @comment.content, comment_data['content']
    assert_equal @user.id, comment_data['author_info']['id']
    assert_equal @user.nickname, comment_data['author_info']['nickname']
    assert comment_data['time_ago']
    assert_equal true, comment_data['can_edit_current_user'] # 作者可以编辑
  end

  test "should include correct can_edit_current_user for different users" do
    # 其他用户查看
    get "/api/posts/#{@post.id}/comments", headers: authenticate_user(@other_user)
    assert_response :success

    json_response = JSON.parse(response.body)
    comment_data = json_response['data'].first
    assert_equal false, comment_data['can_edit_current_user'] # 其他用户不能编辑

    # 管理员查看
    get "/api/posts/#{@post.id}/comments", headers: authenticate_user(@admin)
    assert_response :success

    json_response = JSON.parse(response.body)
    comment_data = json_response['data'].first
    assert_equal true, comment_data['can_edit_current_user'] # 管理员可以编辑
  end

  test "should return empty array for post with no comments" do
    empty_post = create_test_post(user: @other_user)

    get "/api/posts/#{empty_post.id}/comments", headers: authenticate_user(@user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal [], json_response['data']
  end

  test "should return not found for non-existent post" do
    get "/api/posts/99999/comments", headers: authenticate_user(@user)
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_equal false, json_response['success']
    assert_equal '帖子不存在', json_response['error']
  end

  test "should order comments by created_at ascending" do
    # 创建多个评论
    comment1 = Comment.create!(content: "First comment", user: @user, post: @post, commentable: @post, created_at: 1.hour.ago)
    comment2 = Comment.create!(content: "Second comment", user: @other_user, post: @post, commentable: @post, created_at: 30.minutes.ago)
    comment3 = Comment.create!(content: "Third comment", user: @user, post: @post, commentable: @post, created_at: 2.hours.ago)

    get "/api/posts/#{@post.id}/comments", headers: authenticate_user(@user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 4, json_response.length # 包括 setup 中创建的评论

    # 检查排序（最旧的在前）
    assert_equal comment3.content, json_response[0]['content']
    assert_equal comment1.content, json_response[1]['content']
    assert_equal comment2.content, json_response[2]['content']
    assert_equal @comment.content, json_response[3]['content']
  end

  # Create Tests
  test "should create comment with valid data" do
    comment_params = { comment: { content: "This is a new comment" } }

    post "/api/posts/#{@post.id}/comments", params: comment_params, headers: authenticate_user(@user)
    assert_response :created

    json_response = JSON.parse(response.body)
    assert_equal true, json_response['success']
    assert_equal '评论发布成功', json_response['message']
    assert json_response['data']
    assert_equal "This is a new comment", json_response['data']['content']
    assert_equal true, json_response['data']['can_edit_current_user']

    # 验证评论确实被创建了
    assert_equal "This is a new comment", Comment.last.content
  end

  test "should not create comment without content" do
    comment_params = { comment: { content: "" } }

    post "/api/posts/#{@post.id}/comments", params: comment_params, headers: authenticate_user(@user)
    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert json_response['errors']
    assert_includes json_response['errors'], "内容不能为空"
  end

  test "should not create comment with too short content" do
    comment_params = { comment: { content: "a" } }

    post "/api/posts/#{@post.id}/comments", params: comment_params, headers: authenticate_user(@user)
    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert json_response['errors']
    assert_includes json_response['errors'], "内容太短（最少2个字符）"
  end

  test "should not create comment with too long content" do
    long_content = "a" * 1001
    comment_params = { comment: { content: long_content } }

    post "/api/posts/#{@post.id}/comments", params: comment_params, headers: authenticate_user(@user)
    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert json_response['errors']
    assert_includes json_response['errors'], "内容太长（最多1000个字符）"
  end

  test "should not create comment for non-existent post" do
    comment_params = { comment: { content: "This is a new comment" } }

    post "/api/posts/99999/comments", params: comment_params, headers: authenticate_user(@user)
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_equal '帖子不存在', json_response['error']
  end

  test "should create comment for different users" do
    comment_params = { comment: { content: "Comment from other user" } }

    post "/api/posts/#{@post.id}/comments", params: comment_params, headers: authenticate_user(@other_user)
    assert_response :created

    json_response = JSON.parse(response.body)
    assert_equal "Comment from other user", json_response['comment']['content']
    assert_equal @other_user.id, json_response['comment']['author_info']['id']
    assert_equal true, json_response['comment']['can_edit_current_user'] # 作者可以编辑
  end

  # Update Tests
  test "should update comment as author" do
    update_params = { comment: { content: "Updated comment content" } }

    put "/api/comments/#{@comment.id}", params: update_params, headers: authenticate_user(@user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal '评论更新成功', json_response['message']
    assert_equal "Updated comment content", json_response['comment']['content']
    assert_equal true, json_response['comment']['can_edit_current_user']

    # 验证数据库中的内容
    @comment.reload
    assert_equal "Updated comment content", @comment.content
  end

  test "should update comment as admin" do
    update_params = { comment: { content: "Admin updated comment" } }

    put "/api/comments/#{@comment.id}", params: update_params, headers: authenticate_user(@admin)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 'Admin updated comment', json_response['comment']['content']
  end

  test "should not update comment as other user" do
    update_params = { comment: { content: "Hacked comment" } }

    put "/api/comments/#{@comment.id}", params: update_params, headers: authenticate_user(@other_user)
    assert_response :forbidden

    json_response = JSON.parse(response.body)
    assert_equal '无权限编辑此评论', json_response['error']

    # 验证内容没有被修改
    @comment.reload
    assert_equal "Test comment", @comment.content
  end

  test "should not update comment with invalid data" do
    update_params = { comment: { content: "" } }

    put "/api/comments/#{@comment.id}", params: update_params, headers: authenticate_user(@user)
    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert json_response['errors']
  end

  test "should return not found when updating non-existent comment" do
    update_params = { comment: { content: "Updated content" } }

    put "/api/comments/99999", params: update_params, headers: authenticate_user(@user)
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_equal '评论不存在', json_response['error']
  end

  # Destroy Tests
  test "should delete comment as author" do
    delete "/api/comments/#{@comment.id}", headers: authenticate_user(@user)
    assert_response :no_content

    # 验证评论被删除了
    assert_not Comment.exists?(@comment.id)
  end

  test "should delete comment as admin" do
    delete "/api/comments/#{@comment.id}", headers: authenticate_user(@admin)
    assert_response :no_content

    # 验证评论被删除了
    assert_not Comment.exists?(@comment.id)
  end

  test "should not delete comment as other user" do
    delete "/api/comments/#{@comment.id}", headers: authenticate_user(@other_user)
    assert_response :forbidden

    json_response = JSON.parse(response.body)
    assert_equal '无权限删除此评论', json_response['error']

    # 验证评论仍然存在
    assert Comment.exists?(@comment.id)
  end

  test "should return not found when deleting non-existent comment" do
    delete "/api/comments/99999", headers: authenticate_user(@user)
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_equal '评论不存在', json_response['error']
  end

  # Permission Tests
  test "should handle role changes correctly" do
    # 普通用户不能编辑其他人的评论
    put "/api/comments/#{@comment.id}", params: { comment: { content: "Should not work" } }, headers: authenticate_user(@other_user)
    assert_response :forbidden

    # 提升为管理员
    @other_user.update!(role: 1)

    # 现在可以编辑了
    put "/api/comments/#{@comment.id}", params: { comment: { content: "Now it works" } }, headers: authenticate_user(@other_user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "Now it works", json_response['comment']['content']
  end

  # Integration Tests
  test "should handle comment lifecycle" do
    # 1. 创建评论
    comment_params = { comment: { content: "Lifecycle test comment" } }
    post "/api/posts/#{@post.id}/comments", params: comment_params, headers: authenticate_user(@user)
    assert_response :created

    create_response = JSON.parse(response.body)
    comment_id = create_response['comment']['id']

    # 2. 查看评论列表
    get "/api/posts/#{@post.id}/comments", headers: authenticate_user(@user)
    assert_response :success

    list_response = JSON.parse(response.body)
    assert_includes list_response.map { |c| c['id'] }, comment_id

    # 3. 更新评论
    update_params = { comment: { content: "Updated lifecycle comment" } }
    put "/api/comments/#{comment_id}", params: update_params, headers: authenticate_user(@user)
    assert_response :success

    # 4. 删除评论
    delete "/api/comments/#{comment_id}", headers: authenticate_user(@user)
    assert_response :no_content

    # 5. 验证评论被删除
    get "/api/posts/#{@post.id}/comments", headers: authenticate_user(@user)
    assert_response :success

    final_list = JSON.parse(response.body)
    assert_not_includes final_list.map { |c| c['id'] }, comment_id
  end

  # Edge Cases Tests
  test "should handle multiple comments from same user" do
    # 创建多个评论
    comment1_params = { comment: { content: "First comment" } }
    comment2_params = { comment: { content: "Second comment" } }

    post "/api/posts/#{@post.id}/comments", params: comment1_params, headers: authenticate_user(@user)
    assert_response :created

    post "/api/posts/#{@post.id}/comments", params: comment2_params, headers: authenticate_user(@user)
    assert_response :created

    # 验证两个评论都存在
    get "/api/posts/#{@post.id}/comments", headers: authenticate_user(@user)
    assert_response :success

    json_response = JSON.parse(response.body)
    user_comments = json_response.select { |c| c['author_info']['id'] == @user.id }
    assert_equal 3, user_comments.length # 包括 setup 中的评论

    # 所有评论都应该可以编辑
    user_comments.each do |comment|
      assert_equal true, comment['can_edit_current_user']
    end
  end

  test "should handle comments with unicode content" do
    unicode_params = { comment: { content: "这是一个包含中文的评论 🎉" } }

    post "/api/posts/#{@post.id}/comments", params: unicode_params, headers: authenticate_user(@user)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "这是一个包含中文的评论 🎉", json_response['comment']['content']
  end

  private

  def authenticate_user(user)
    token = user.generate_jwt_token
    { "Authorization" => "Bearer #{token}" }
  end
end