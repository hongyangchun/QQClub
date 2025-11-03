# frozen_string_literal: true

require "test_helper"

class Api::V1::FlowerCommentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user(:user)
    @admin = create_test_user(:admin)
    @event = create_test_reading_event(
      title: "测试阅读活动",
      start_date: Date.today,
      end_date: Date.today + 7.days,
      status: 'in_progress'
    )

    # 创建用户报名
    @enrollment = EventEnrollment.create!(
      user: @user,
      reading_event: @event,
      enrollment_type: 'participant',
      status: 'enrolled',
      enrollment_date: Time.current
    )

    # 创建打卡记录
    @check_in = CheckIn.create!(
      user: @user,
      reading_schedule: create_test_reading_schedule(reading_event: @event),
      enrollment: @enrollment,
      content: "今天的阅读内容很有意思，学到了很多新知识。这是一段满足最低字数要求的测试内容，确保打卡能够成功创建。" * 2,
      status: 'normal',
      submitted_at: Time.current
    )

    # 创建小红花
    @flower = Flower.create!(
      check_in: @check_in,
      giver: @admin,
      recipient: @user,
      amount: 1,
      flower_type: 'regular',
      is_anonymous: false
    )

    # 创建认证令牌
    @token = JwtService.encode(user_id: @user.id)
    @admin_token = JwtService.encode(user_id: @admin.id)
  end

  def teardown
    # 清理测试数据
    Comment.delete_all
    Flower.delete_all
    CheckIn.delete_all
    EventEnrollment.delete_all
    ReadingSchedule.delete_all
    ReadingEvent.delete_all
    User.delete_all
  end

  # ============================================================================
  # 测试评论创建
  # ============================================================================

  test "should create comment on flower as recipient" do
    assert_difference('Comment.count') do
      post api_v1_flower_comments_path(@flower),
        params: { comment: { content: "感谢这朵小红花！" } },
        headers: { 'Authorization' => "Bearer #{@token}" }
    end

    assert_response :created

    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal '评论添加成功', json_response['message']
    assert json_response['comment']
    assert_equal '感谢这朵小红花！', json_response['comment']['content']
  end

  test "should create comment on flower as giver" do
    assert_difference('Comment.count') do
      post api_v1_flower_comments_path(@flower),
        params: { comment: { content: "你的表现很棒！" } },
        headers: { 'Authorization' => "Bearer #{@admin_token}" }
    end

    assert_response :created

    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal '你的表现很棒！', json_response['comment']['content']
  end

  test "should not create comment without authentication" do
    post api_v1_flower_comments_path(@flower),
      params: { comment: { content: "未认证评论" } }

    assert_response :unauthorized
  end

  test "should not create comment with empty content" do
    post api_v1_flower_comments_path(@flower),
      params: { comment: { content: "" } },
      headers: { 'Authorization' => "Bearer #{@token}" }

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_equal '评论内容长度应在2-1000字符之间', json_response['error']
  end

  test "should not create comment with too long content" do
    long_content = "a" * 1001

    post api_v1_flower_comments_path(@flower),
      params: { comment: { content: long_content } },
      headers: { 'Authorization' => "Bearer #{@token}" }

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_equal '评论内容长度应在2-1000字符之间', json_response['error']
  end

  test "should not create comment without permission" do
    # 创建没有权限的用户
    other_user = create_test_user(:user, nickname: "其他用户")
    other_token = JwtService.encode(user_id: other_user.id)

    post api_v1_flower_comments_path(@flower),
      params: { comment: { content: "我没有权限的评论" } },
      headers: { 'Authorization' => "Bearer #{other_token}" }

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_equal '您没有权限评论此小红花', json_response['error']
  end

  # ============================================================================
  # 测试评论列表获取
  # ============================================================================

  test "should get comments for flower" do
    # 创建一些评论
    Comment.create!(
      commentable: @flower,
      user: @admin,
      content: "管理员评论",
      created_at: 1.hour.ago
    )

    Comment.create!(
      commentable: @flower,
      user: @user,
      content: "用户评论",
      created_at: 30.minutes.ago
    )

    get api_v1_flower_comments_path(@flower),
      headers: { 'Authorization' => "Bearer #{@token}" }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal 2, json_response['comments'].length
    assert_equal '用户评论', json_response['comments'][0]['content']  # 最新的在前
    assert_equal '管理员评论', json_response['comments'][1]['content']

    # 检查分页信息
    pagination = json_response['pagination']
    assert_equal 1, pagination['current_page']
    assert_equal 2, pagination['total_count']
    assert_equal 1, pagination['total_pages']
    assert_not pagination['has_next']
    assert_not pagination['has_prev']
  end

  test "should paginate comments correctly" do
    # 创建超过默认分页数量的评论
    (1..15).each do |i|
      Comment.create!(
        commentable: @flower,
        user: @user,
        content: "评论 #{i}",
        created_at: (15 - i).hours.ago
      )
    end

    # 获取第一页
    get api_v1_flower_comments_path(@flower),
      params: { page: 1, limit: 5 },
      headers: { 'Authorization' => "Bearer #{@token}" }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 5, json_response['comments'].length
    assert_equal '评论 15', json_response['comments'][0]['content']  # 最新的

    pagination = json_response['pagination']
    assert_equal 1, pagination['current_page']
    assert_equal 15, pagination['total_count']
    assert_equal 3, pagination['total_pages']
    assert pagination['has_next']
    assert_not pagination['has_prev']
  end

  test "should get comments without authentication" do
    get api_v1_flower_comments_path(@flower)

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal 0, json_response['comments'].length

    # 检查权限信息
    permissions = json_response['permissions']
    assert_not permissions['can_comment']
  end

  # ============================================================================
  # 测试评论统计
  # ============================================================================

  test "should get comment statistics for flower" do
    # 创建不同时间的评论
    Comment.create!(commentable: @flower, user: @user, content: "今天的评论", created_at: Time.current)
    Comment.create!(commentable: @flower, user: @admin, content: "昨天的评论", created_at: 1.day.ago)
    Comment.create!(commentable: @flower, user: @user, content: "本周的评论", created_at: 3.days.ago)

    get stats_api_v1_flower_comments_path(@flower),
      headers: { 'Authorization' => "Bearer #{@token}" }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal @flower.id, json_response['flower_id']

    stats = json_response['stats']
    assert_equal 3, stats['total_count']
    assert_equal 1, stats['today_count']
    assert stats['this_week_count'] >= 3
    assert_equal 2, stats['unique_users']

    # 检查活跃评论者
    active_commenters = json_response['active_commenters']
    assert_equal 2, active_commenters.length

    user_commenter = active_commenters.find { |c| c['user_id'] == @user.id }
    assert_equal 2, user_commenter['comment_count']
  end

  # ============================================================================
  # 测试评论搜索
  # ============================================================================

  test "should search comments by keyword" do
    # 创建包含不同关键词的评论
    Comment.create!(commentable: @flower, user: @user, content: "很棒的分享，学到了很多")
    Comment.create!(commentable: @flower, user: @admin, content: "不错的表现")
    Comment.create!(commentable: @flower, user: @user, content: "非常棒的内容")

    get search_api_v1_flower_comments_path(@flower),
      params: { q: "棒" },
      headers: { 'Authorization' => "Bearer #{@token}" }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal '棒', json_response['keyword']
    assert_equal 2, json_response['results'].length

    # 检查关键词高亮
    first_result = json_response['results'][0]
    assert_includes first_result['highlighted_content'], '**棒**'
  end

  test "should return empty results for non-existent keyword" do
    get search_api_v1_flower_comments_path(@flower),
      params: { q: "不存在的关键词" },
      headers: { 'Authorization' => "Bearer #{@token}" }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal 0, json_response['results'].length
  end

  # ============================================================================
  # 测试评论删除
  # ============================================================================

  test "should delete own comment" do
    comment = Comment.create!(
      commentable: @flower,
      user: @user,
      content: "我要删除的评论"
    )

    delete api_v1_flower_comment_path(@flower, comment),
      headers: { 'Authorization' => "Bearer #{@token}" }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal '评论已删除', json_response['message']
    assert_equal 0, Comment.where(id: comment.id).count
  end

  test "should delete comment as flower recipient" do
    comment = Comment.create!(
      commentable: @flower,
      user: @admin,
      content: "管理员要删除的评论"
    )

    # 小红花接收者可以删除关于自己的小红花的评论
    delete api_v1_flower_comment_path(@flower, comment),
      headers: { 'Authorization' => "Bearer #{@token}" }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal '评论已删除', json_response['message']
  end

  test "should delete comment as admin" do
    comment = Comment.create!(
      commentable: @flower,
      user: @user,
      content: "管理员要删除的评论"
    )

    delete api_v1_flower_comment_path(@flower, comment),
      headers: { 'Authorization' => "Bearer #{@admin_token}" }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal '评论已删除', json_response['message']
  end

  test "should not delete comment without permission" do
    other_user = create_test_user(:user, nickname: "其他用户")
    other_token = JwtService.encode(user_id: other_user.id)

    comment = Comment.create!(
      commentable: @flower,
      user: @user,
      content: "不能被删除的评论"
    )

    delete api_v1_flower_comment_path(@flower, comment),
      headers: { 'Authorization' => "Bearer #{other_token}" }

    assert_response :forbidden

    json_response = JSON.parse(response.body)
    assert_equal '您没有权限删除此评论', json_response['error']
  end

  # ============================================================================
  # 测试批量删除
  # ============================================================================

  test "should batch delete comments as admin" do
    comment1 = Comment.create!(commentable: @flower, user: @user, content: "评论1")
    comment2 = Comment.create!(commentable: @flower, user: @admin, content: "评论2")
    comment3 = Comment.create!(commentable: @flower, user: @user, content: "评论3")

    delete batch_api_v1_flower_comments_path(@flower),
      params: { comment_ids: [comment1.id, comment3.id] },
      headers: { 'Authorization' => "Bearer #{@admin_token}" }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal "所有评论已删除", json_response['message']
    assert_equal 2, json_response['deleted_count']
    assert_equal 1, Comment.count  # 只剩 comment2
  end

  test "should not batch delete comments without admin permission" do
    delete batch_api_v1_flower_comments_path(@flower),
      params: { comment_ids: [1, 2, 3] },
      headers: { 'Authorization' => "Bearer #{@token}" }

    assert_response :forbidden

    json_response = JSON.parse(response.body)
    assert_equal '需要管理员权限', json_response['error']
  end

  # ============================================================================
  # 测试错误处理
  # ============================================================================

  test "should handle non-existent flower" do
    post api_v1_flower_comments_path(99999),
      params: { comment: { content: "给不存在的小红花的评论" } },
      headers: { 'Authorization' => "Bearer #{@token}" }

    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_equal '小红花不存在', json_response['error']
  end

  test "should handle non-existent comment" do
    delete api_v1_flower_comment_path(@flower, 99999),
      headers: { 'Authorization' => "Bearer #{@token}" }

    assert_response :not_found
  end

  test "should handle invalid parameters gracefully" do
    post api_v1_flower_comments_path(@flower),
      params: { invalid_param: "invalid" },
      headers: { 'Authorization' => "Bearer #{@token}" }

    assert_response :bad_request
  end
end