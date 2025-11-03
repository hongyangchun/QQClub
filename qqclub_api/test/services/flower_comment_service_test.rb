# frozen_string_literal: true

require "test_helper"

class FlowerCommentServiceTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user(:user)
    @admin = create_test_user(:admin)
    @other_user = create_test_user(:user, nickname: "其他用户")

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
  # 测试添加评论
  # ============================================================================

  test "add_comment_to_flower should create comment successfully" do
    result = FlowerCommentService.add_comment_to_flower(@flower, @user, "很棒的分享！")

    assert result[:success]
    assert_equal "评论添加成功", result[:message]
    assert_not_nil result[:comment]
    assert_equal "很棒的分享！", result[:comment]['content']
    assert_equal @user.id, result[:comment]['user_id']
    assert_equal @flower.id, result[:comment]['commentable_id']

    # 验证数据库中的记录
    assert_equal 1, Comment.count
    comment = Comment.first
    assert_equal "很棒的分享！", comment.content
    assert_equal @user, comment.user
    assert_equal @flower, comment.commentable
  end

  test "add_comment_to_flower should validate flower existence" do
    result = FlowerCommentService.add_comment_to_flower(nil, @user, "评论内容")

    assert_not result[:success]
    assert_equal "小红花不存在", result[:error]
    assert_equal 0, Comment.count
  end

  test "add_comment_to_flower should validate user existence" do
    result = FlowerCommentService.add_comment_to_flower(@flower, nil, "评论内容")

    assert_not result[:success]
    assert_equal "用户不存在", result[:error]
    assert_equal 0, Comment.count
  end

  test "add_comment_to_flower should validate content not empty" do
    result = FlowerCommentService.add_comment_to_flower(@flower, @user, "")

    assert_not result[:success]
    assert_equal "评论内容不能为空", result[:error]
    assert_equal 0, Comment.count
  end

  test "add_comment_to_flower should validate content length" do
    # 测试太短的内容
    result = FlowerCommentService.add_comment_to_flower(@flower, @user, "a")
    assert_not result[:success]
    assert_equal "评论内容长度应在2-1000字符之间", result[:error]

    # 测试太长的内容
    long_content = "a" * 1001
    result = FlowerCommentService.add_comment_to_flower(@flower, @user, long_content)
    assert_not result[:success]
    assert_equal "评论内容长度应在2-1000字符之间", result[:error]

    assert_equal 0, Comment.count
  end

  test "add_comment_to_flower should check comment permission" do
    # 测试没有权限的用户
    result = FlowerCommentService.add_comment_to_flower(@flower, @other_user, "无权限评论")

    assert_not result[:success]
    assert_equal "您没有权限评论此小红花", result[:error]
    assert_equal 0, Comment.count
  end

  test "add_comment_to_flower should allow recipient to comment" do
    result = FlowerCommentService.add_comment_to_flower(@flower, @user, "接收者评论")

    assert result[:success]
    assert_equal 1, Comment.count
  end

  test "add_comment_to_flower should allow giver to comment" do
    result = FlowerCommentService.add_comment_to_flower(@flower, @admin, "赠送者评论")

    assert result[:success]
    assert_equal 1, Comment.count
  end

  test "add_comment_to_flower should handle participants" do
    # 将其他用户添加为活动参与者
    EventEnrollment.create!(
      user: @other_user,
      reading_event: @event,
      enrollment_type: 'participant',
      status: 'enrolled',
      enrollment_date: Time.current
    )

    result = FlowerCommentService.add_comment_to_flower(@flower, @other_user, "参与者评论")

    assert result[:success]
    assert_equal 1, Comment.count
  end

  # ============================================================================
  # 测试获取评论列表
  # ============================================================================

  test "get_flower_comments should return paginated comments" do
    # 创建一些评论
    comment1 = Comment.create!(commentable: @flower, user: @user, content: "评论1", created_at: 2.hours.ago)
    comment2 = Comment.create!(commentable: @flower, user: @admin, content: "评论2", created_at: 1.hour.ago)
    comment3 = Comment.create!(commentable: @flower, user: @user, content: "评论3", created_at: 30.minutes.ago)

    result = FlowerCommentService.get_flower_comments(@flower, 1, 2, @user)

    assert result[:success]
    assert_equal 3, result[:pagination][:total_count]
    assert_equal 2, result[:comments].length

    # 检查排序（最新的在前）
    assert_equal "评论3", result[:comments][0]['content']
    assert_equal "评论2", result[:comments][1]['content']

    # 检查分页信息
    pagination = result[:pagination]
    assert_equal 1, pagination[:current_page]
    assert_equal 2, pagination[:total_pages]
    assert pagination[:has_next]
    assert_not pagination[:has_prev]
  end

  test "get_flower_comments should check user permissions" do
    result = FlowerCommentService.get_flower_comments(@flower, 1, 10, @user)

    assert result[:success]
    assert result[:permissions][:can_comment]  # 小红花接收者有权限

    result = FlowerCommentService.get_flower_comments(@flower, 1, 10, @other_user)

    assert result[:success]
    assert_not result[:permissions][:can_comment]  # 无权限用户

    result = FlowerCommentService.get_flower_comments(@flower, 1, 10, nil)

    assert result[:success]
    assert_not result[:permissions][:can_comment]  # 未登录用户
  end

  test "get_flower_comments should handle non-existent flower" do
    result = FlowerCommentService.get_flower_comments(nil, 1, 10, @user)

    assert_not result[:success]
    assert_equal "小红花不存在", result[:error]
  end

  # ============================================================================
  # 测试评论统计
  # ============================================================================

  test "get_flower_comment_stats should return correct statistics" do
    # 创建不同时间的评论
    Comment.create!(commentable: @flower, user: @user, content: "今天的评论", created_at: Time.current)
    Comment.create!(commentable: @flower, user: @admin, content: "昨天的评论", created_at: 1.day.ago)
    Comment.create!(commentable: @flower, user: @user, content: "本周的评论", created_at: 3.days.ago)
    Comment.create!(commentable: @flower, user: @user, content: "长评论内容测试长度", created_at: 5.days.ago)

    result = FlowerCommentService.get_flower_comment_stats(@flower)

    assert result[:success]
    assert_equal @flower.id, result[:flower_id]

    stats = result[:stats]
    assert_equal 4, stats[:total_count]
    assert_equal 1, stats[:today_count]
    assert stats[:this_week_count] >= 4
    assert_equal 2, stats[:unique_users]
    assert stats[:avg_comment_length] > 0

    # 检查活跃评论者
    active_commenters = result[:active_commenters]
    assert_equal 2, active_commenters.length

    user_commenter = active_commenters.find { |c| c[:user_id] == @user.id }
    assert_equal 3, user_commenter[:comment_count]

    # 检查最新评论
    assert_not_nil result[:latest_comment]
    assert_equal "今天的评论", result[:latest_comment]['content']
  end

  test "get_flower_comment_stats should handle flower with no comments" do
    result = FlowerCommentService.get_flower_comment_stats(@flower)

    assert result[:success]
    assert_equal @flower.id, result[:flower_id]

    stats = result[:stats]
    assert_equal 0, stats[:total_count]
    assert_equal 0, stats[:today_count]
    assert_equal 0, stats[:unique_users]
    assert_equal 0, stats[:avg_comment_length]

    assert_empty result[:active_commenters]
    assert_nil result[:latest_comment]
  end

  # ============================================================================
  # 测试删除评论
  # ============================================================================

  test "delete_flower_comment should allow user to delete own comment" do
    comment = Comment.create!(commentable: @flower, user: @user, content: "要删除的评论")

    result = FlowerCommentService.delete_flower_comment(@flower, comment, @user)

    assert result[:success]
    assert_equal "评论已删除", result[:message]
    assert_equal 0, Comment.count
  end

  test "delete_flower_comment should allow admin to delete any comment" do
    comment = Comment.create!(commentable: @flower, user: @user, content: "管理员要删除的评论")

    result = FlowerCommentService.delete_flower_comment(@flower, comment, @admin)

    assert result[:success]
    assert_equal "评论已删除", result[:message]
    assert_equal 0, Comment.count
  end

  test "delete_flower_comment should allow flower recipient to delete comment" do
    comment = Comment.create!(commentable: @flower, user: @admin, content: "接收者要删除的评论")

    result = FlowerCommentService.delete_flower_comment(@flower, comment, @user)

    assert result[:success]
    assert_equal "评论已删除", result[:message]
    assert_equal 0, Comment.count
  end

  test "delete_flower_comment should not allow unauthorized deletion" do
    comment = Comment.create!(commentable: @flower, user: @user, content: "不能删除的评论")

    result = FlowerCommentService.delete_flower_comment(@flower, comment, @other_user)

    assert_not result[:success]
    assert_equal "您没有权限删除此评论", result[:error]
    assert_equal 1, Comment.count
  end

  test "delete_flower_comment should handle non-existent comment" do
    result = FlowerCommentService.delete_flower_comment(@flower, nil, @user)

    assert_not result[:success]
    assert_equal "评论不存在", result[:error]
  end

  # ============================================================================
  # 测试批量删除
  # ============================================================================

  test "batch_delete_flower_comments should delete multiple comments" do
    comment1 = Comment.create!(commentable: @flower, user: @user, content: "评论1")
    comment2 = Comment.create!(commentable: @flower, user: @admin, content: "评论2")
    comment3 = Comment.create!(commentable: @flower, user: @user, content: "评论3")

    result = FlowerCommentService.batch_delete_flower_comments(@flower, [comment1.id, comment3.id], @admin)

    assert result[:success]
    assert_equal "所有评论已删除", result[:message]
    assert_equal 2, result[:deleted_count]
    assert_equal 0, result[:failed_count]
    assert_equal 1, Comment.count  # 只剩 comment2
  end

  test "batch_delete_flower_comments should require admin permission" do
    result = FlowerCommentService.batch_delete_flower_comments(@flower, [1, 2, 3], @user)

    assert_not result[:success]
    assert_equal "需要管理员权限", result[:error]
  end

  test "batch_delete_flower_comments should handle partial failures" do
    comment1 = Comment.create!(commentable: @flower, user: @user, content: "评论1")

    # 尝试删除存在的评论和不存在的评论
    result = FlowerCommentService.batch_delete_flower_comments(@flower, [comment1.id, 99999], @admin)

    assert result[:success]
    assert_equal "部分评论删除失败", result[:message]
    assert_equal 1, result[:deleted_count]
    assert_equal 1, result[:failed_count]
    assert_includes result[:failed_comment_ids], 99999
  end

  # ============================================================================
  # 测试搜索评论
  # ============================================================================

  test "search_flower_comments should find comments by keyword" do
    Comment.create!(commentable: @flower, user: @user, content: "很棒的分享，学到了很多")
    Comment.create!(commentable: @flower, user: @admin, content: "不错的表现")
    Comment.create!(commentable: @flower, user: @user, content: "非常棒的内容")

    result = FlowerCommentService.search_flower_comments(@flower, "棒", 1, 10, @user)

    assert result[:success]
    assert_equal "棒", result[:keyword]
    assert_equal 2, result[:results].length

    # 检查关键词高亮
    first_result = result[:results][0]
    assert_includes first_result[:highlighted_content], "**棒**"
  end

  test "search_flower_comments should handle empty keyword" do
    result = FlowerCommentService.search_flower_comments(@flower, "", 1, 10, @user)

    assert_not result[:success]
    assert_equal "搜索关键词不能为空", result[:error]
  end

  test "search_flower_comments should handle non-existent flower" do
    result = FlowerCommentService.search_flower_comments(nil, "关键词", 1, 10, @user)

    assert_not result[:success]
    assert_equal "小红花不存在", result[:error]
  end

  test "search_flower_comments should return empty results for no matches" do
    Comment.create!(commentable: @flower, user: @user, content: "不包含关键词的评论")

    result = FlowerCommentService.search_flower_comments(@flower, "不存在的关键词", 1, 10, @user)

    assert result[:success]
    assert_equal 0, result[:results].length
  end

  # ============================================================================
  # 测试私有方法
  # ============================================================================

  test "can_comment_on_flower should work correctly" do
    # 小红花接收者可以评论
    assert FlowerCommentService.send(:can_comment_on_flower?, @flower, @user)

    # 小红花赠送者可以评论
    assert FlowerCommentService.send(:can_comment_on_flower?, @flower, @admin)

    # 无权限用户不能评论
    assert_not FlowerCommentService.send(:can_comment_on_flower?, @flower, @other_user)

    # 活动参与者可以评论
    EventEnrollment.create!(
      user: @other_user,
      reading_event: @event,
      enrollment_type: 'participant',
      status: 'enrolled',
      enrollment_date: Time.current
    )
    assert FlowerCommentService.send(:can_comment_on_flower?, @flower, @other_user)
  end

  test "can_delete_comment should work correctly" do
    comment = Comment.create!(commentable: @flower, user: @user, content: "测试评论")

    # 评论作者可以删除
    assert FlowerCommentService.send(:can_delete_comment?, comment, @user)

    # 管理员可以删除
    assert FlowerCommentService.send(:can_delete_comment?, comment, @admin)

    # 小红花接收者可以删除
    assert FlowerCommentService.send(:can_delete_comment?, comment, @user)

    # 无权限用户不能删除
    assert_not FlowerCommentService.send(:can_delete_comment?, comment, @other_user)
  end

  test "valid_comment_content should validate correctly" do
    # 有效内容
    assert FlowerCommentService.send(:valid_comment_content?, "有效的评论内容")
    assert FlowerCommentService.send(:valid_comment_content?, "a" * 1000)

    # 无效内容
    assert_not FlowerCommentService.send(:valid_comment_content?, "")
    assert_not FlowerCommentService.send(:valid_comment_content?, "a")  # 太短
    assert_not FlowerCommentService.send(:valid_comment_content?, "a" * 1001)  # 太长
    assert_not FlowerCommentService.send(:valid_comment_content?, "   ")  # 只有空格
  end
end