# frozen_string_literal: true

require "test_helper"

class ReadingEventLifecycleTest < ActionDispatch::IntegrationTest
  def setup
    @creator = create_test_user(:user)
    @admin = create_test_user(:admin)
    @participant1 = create_test_user(:user)
    @participant2 = create_test_user(:user)
    @participant3 = create_test_user(:user)
  end

  # 完整活动生命周期测试
  test "should handle complete reading event lifecycle from creation to completion" do
    # Phase 1: 活动创建
    event_data = {
      title: "《深度工作》精读营",
      book_name: "深度工作",
      description: "学习专注和高效工作的方法论",
      start_date: Date.current + 14.days,
      end_date: Date.current + 42.days,
      max_participants: 10,
      min_participants: 3,
      fee_type: "free",
      fee_amount: 0,
      leader_reward_percentage: 10,
      completion_standard: 80,
      activity_mode: "note_checkin",
      leader_assignment_type: "voluntary",
      weekend_rest: true
    }

    creator_headers = authenticate_user(@creator)

    post api_v1_reading_events_path, params: event_data, headers: creator_headers
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]
    assert_not_nil event_id

    # Phase 2: 活动审批
    admin_headers = authenticate_user(@admin)

    post approve_api_v1_reading_event_path(event_id), headers: admin_headers
    assert_response :success

    # Phase 3: 设置阅读计划
    7.times do |i|
      ReadingSchedule.create!(
        reading_event_id: event_id,
        date: Date.current + 14.days + i.days,
        day_number: i + 1,
        reading_progress: "第#{i + 1}章"
      )
    end

    # Phase 4: 用户报名
    participants = [@participant1, @participant2, @participant3]

    participants.each do |participant|
      participant_headers = authenticate_user(participant)

      post api_v1_event_enrollments_path(event_id), headers: participant_headers
      assert_response :success

      enrollment_response = JSON.parse(response.body)
      assert_equal "报名成功", enrollment_response["message"]
    end

    # Phase 5: 验证报名状态
    get api_v1_reading_event_path(event_id), headers: creator_headers
    assert_response :success

    event_detail = JSON.parse(response.body)
    assert_equal 3, event_detail["current_participants"]

    # Phase 6: 领读人分配（自愿模式）
    first_schedule = ReadingSchedule.where(reading_event_id: event_id).first
    leader_assignment_data = {
      reading_schedule_id: first_schedule.id,
      user_id: @participant1.id
    }

    post api_v1_claim_leadership_path(event_id), params: leader_assignment_data, headers: authenticate_user(@participant1)
    assert_response :success

    # Phase 7: 模拟活动开始
    patch api_v1_reading_event_path(event_id), params: { status: "in_progress" }, headers: admin_headers
    assert_response :success

    # Phase 8: 打卡和领读内容发布
    # 参与者打卡
    check_in_data = {
      content: "今天读了第1章，学到了专注的重要性",
      reading_schedule_id: first_schedule.id
    }

    post api_v1_check_ins_path, params: check_in_data, headers: authenticate_user(@participant2)
    assert_response :success

    # 领读人发布内容
    leading_content_data = {
      reading_schedule_id: first_schedule.id,
      content: "第1章要点：深度工作的价值、浮浅工作的危害、如何训练专注力",
      summary: "本章介绍了深度工作的重要性，并提供了实用的专注力训练方法"
    }

    post api_v1_daily_leading_path, params: leading_content_data, headers: authenticate_user(@participant1)
    assert_response :success

    # Phase 9: 鲜花互动
    flower_data = {
      receiver_id: @participant1.id,
      reading_schedule_id: first_schedule.id,
      flower_type: "daily_leading",
      reason: "领读内容很棒，总结得很到位！"
    }

    post api_v1_flowers_path, params: flower_data, headers: authenticate_user(@participant2)
    assert_response :success

    # Phase 10: 活动结束和统计
    patch api_v1_reading_event_path(event_id), params: { status: "completed" }, headers: admin_headers
    assert_response :success

    # 验证活动统计
    get api_v1_reading_event_statistics_path(event_id), headers: admin_headers
    assert_response :success

    stats = JSON.parse(response.body)
    assert stats.key?("total_check_ins")
    assert stats.key?("completion_rates")
    assert stats.key?("flower_statistics")
  end

  # 活动拒绝后重新提交的流程测试
  test "should handle rejection and resubmission workflow" do
    # 创建活动
    event_data = {
      title: "测试活动",
      book_name: "测试书籍",
      description: "这是一个测试活动",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 5,
      leader_assignment_type: "voluntary"
    }

    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    # 管理员拒绝活动
    rejection_reason = "活动描述过于简单，请详细说明活动安排和预期效果"
    post reject_api_v1_reading_event_path(event_id),
         params: { reason: rejection_reason },
         headers: authenticate_user(@admin)
    assert_response :success

    # 验证拒绝状态
    get api_v1_reading_event_path(event_id), headers: authenticate_user(@creator)
    event_detail = JSON.parse(response.body)
    assert_equal "rejected", event_detail["approval_status"]
    assert_equal rejection_reason, event_detail["rejection_reason"]

    # 创建者修改活动并重新提交
    updated_data = {
      description: "这是一个为期两周的深度读书活动，每天安排1小时阅读和讨论，通过打卡和领读分享的方式促进学习交流。活动目标是帮助参与者深入理解书籍内容并应用到实际工作中。",
      detailed_schedule: "第1周：基础概念和方法论；第2周：实践应用和案例分析"
    }

    patch api_v1_reading_event_path(event_id), params: updated_data, headers: authenticate_user(@creator)
    assert_response :success

    # 重新提交审批
    post resubmit_api_v1_reading_event_path(event_id), headers: authenticate_user(@creator)
    assert_response :success

    # 验证重新提交状态
    get api_v1_reading_event_path(event_id), headers: authenticate_user(@creator)
    event_detail = JSON.parse(response.body)
    assert_equal "pending", event_detail["approval_status"]
  end

  # 批量审批流程测试
  test "should handle batch approval workflow" do
    # 创建多个待审批活动
    event_ids = []
    3.times do |i|
      event_data = {
        title: "待审批活动#{i + 1}",
        book_name: "测试书籍#{i + 1}",
        description: "这是第#{i + 1}个测试活动",
        start_date: Date.current + 7.days,
        end_date: Date.current + 21.days,
        max_participants: 5
      }

      post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
      assert_response :success

      event_response = JSON.parse(response.body)
      event_ids << event_response["id"]
    end

    # 批量审批
    batch_approval_data = {
      event_ids: event_ids,
      action: "approve",
      reason: "活动内容完整，符合要求"
    }

    post batch_approve_api_v1_reading_events_path, params: batch_approval_data, headers: authenticate_user(@admin)
    assert_response :success

    batch_result = JSON.parse(response.body)
    assert_equal 3, batch_result["successful"]
    assert_equal 0, batch_result["failed"]

    # 验证所有活动都已审批通过
    event_ids.each do |event_id|
      get api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
      event_detail = JSON.parse(response.body)
      assert_equal "approved", event_detail["approval_status"]
    end
  end

  # 活动报名满员处理流程测试
  test "should handle full enrollment scenario" do
    # 创建小容量活动
    event_data = {
      title: "小型读书会",
      book_name: "小而美",
      description: "小规模深度读书活动",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 2,
      min_participants: 2
    }

    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    # 审批通过
    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 前两个用户成功报名
    post api_v1_event_enrollments_path(event_id), headers: authenticate_user(@participant1)
    assert_response :success

    post api_v1_event_enrollments_path(event_id), headers: authenticate_user(@participant2)
    assert_response :success

    # 第三个用户报名失败
    post api_v1_event_enrollments_path(event_id), headers: authenticate_user(@participant3)
    assert_response :unprocessable_entity

    error_response = JSON.parse(response.body)
    assert_includes error_response["error"], "活动已满员"

    # 验证活动状态为满员
    get api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    event_detail = JSON.parse(response.body)
    assert_equal 2, event_detail["current_participants"]
    assert_equal true, event_detail["is_full"]
  end

  # 领读人轮换和补位流程测试
  test "should handle leader rotation and backup workflow" do
    # 创建随机分配领读人的活动
    event_data = {
      title: "轮换领读活动",
      book_name: "领导力",
      description: "通过轮换方式让每个人都有机会领读",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 5,
      leader_assignment_type: "random"
    }

    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    # 审批通过
    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 创建阅读计划
    3.times do |i|
      ReadingSchedule.create!(
        reading_event_id: event_id,
        date: Date.current + 14.days + i.days,
        day_number: i + 1,
        reading_progress: "第#{i + 1}章"
      )
    end

    # 报名用户
    participants = [@participant1, @participant2, @participant3]
    participants.each do |participant|
      post api_v1_event_enrollments_path(event_id), headers: authenticate_user(participant)
      assert_response :success
    end

    # 开始活动并自动分配领读人
    patch api_v1_reading_event_path(event_id), params: { status: "in_progress" }, headers: authenticate_user(@admin)
    assert_response :success

    # 验证领读人分配
    schedules = ReadingSchedule.where(reading_event_id: event_id).includes(:daily_leader)
    schedules.each do |schedule|
      assert_not_nil schedule.daily_leader, "每个日程都应该有领读人"
      assert_includes participants, schedule.daily_leader, "领读人应该是报名参与者之一"
    end

    # 模拟领读人缺席，需要补位
    first_schedule = schedules.first
    original_leader = first_schedule.daily_leader

    # 活动创建者进行补位
    backup_data = {
      reading_schedule_id: first_schedule.id,
      new_leader_id: @creator.id,
      reason: "原领读人临时有事，由活动创建者补位"
    }

    post api_v1_backup_assignment_path(event_id), params: backup_data, headers: authenticate_user(@creator)
    assert_response :success

    # 验证补位成功
    first_schedule.reload
    assert_equal @creator, first_schedule.daily_leader
    assert_not_equal original_leader, first_schedule.daily_leader
  end

  # 活动数据统计和分析流程测试
  test "should handle comprehensive event analytics workflow" do
    # 创建并开始活动
    event_data = {
      title: "数据分析活动",
      book_name: "数据驱动决策",
      description: "通过数据分析提升决策质量",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 5
    }

    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 创建阅读计划
    5.times do |i|
      ReadingSchedule.create!(
        reading_event_id: event_id,
        date: Date.current + 14.days + i.days,
        day_number: i + 1,
        reading_progress: "第#{i + 1}章"
      )
    end

    # 多个用户报名
    participants = [@participant1, @participant2, @participant3]
    participants.each do |participant|
      post api_v1_event_enrollments_path(event_id), headers: authenticate_user(participant)
      assert_response :success
    end

    # 开始活动
    patch api_v1_reading_event_path(event_id), params: { status: "in_progress" }, headers: authenticate_user(@admin)
    assert_response :success

    # 模拟用户活动数据
    schedules = ReadingSchedule.where(reading_event_id: event_id)

    # 打卡数据
    schedules.each_with_index do |schedule, index|
      next if index >= 3 # 只模拟前3天的活动

      # 参与者1和2打卡
      [@participant1, @participant2].each do |participant|
        CheckIn.create!(
          user: participant,
          reading_schedule: schedule,
          content: "学习心得#{index + 1}",
          check_in_date: schedule.date
        )
      end

      # 参与者3只有部分打卡
      if index < 2
        CheckIn.create!(
          user: @participant3,
          reading_schedule: schedule,
          content: "部分参与#{index + 1}",
          check_in_date: schedule.date
        )
      end
    end

    # 领读内容
    first_schedule = schedules.first
    DailyLeading.create!(
      reading_schedule: first_schedule,
      leader: @participant1,
      content: "第一章详细解读",
      published_at: Time.current
    )

    # 鲜花数据
    Flower.create!(
      giver: @participant2,
      receiver: @participant1,
      reading_schedule: first_schedule,
      flower_type: "daily_leading",
      reason: "内容很棒"
    )

    # 获取活动统计
    get api_v1_reading_event_analytics_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    analytics = JSON.parse(response.body)

    # 验证统计数据
    assert analytics.key?("participation_rate")
    assert analytics.key?("completion_rate")
    assert analytics.key?("engagement_metrics")
    assert analytics.key?("flower_statistics")
    assert analytics.key?("check_in_patterns")

    # 验证具体数据
    assert_equal 3, analytics["total_participants"]
    assert analytics["participation_rate"] > 0
    assert analytics["check_in_count"] > 0
  end

  # 活动异常情况处理流程测试
  test "should handle edge cases and error scenarios" do
    # 测试无效活动数据
    invalid_event_data = {
      title: "",  # 空标题
      book_name: "",
      start_date: Date.current - 1.day,  # 过去的时间
      max_participants: 0,  # 无效的人数
      fee_type: "paid",
      fee_amount: -100  # 负费用
    }

    post api_v1_reading_events_path, params: invalid_event_data, headers: authenticate_user(@creator)
    assert_response :unprocessable_entity

    error_response = JSON.parse(response.body)
    assert error_response.key?("errors")

    # 测试权限不足的情况
    event_data = {
      title: "权限测试活动",
      book_name: "权限",
      description: "测试权限控制",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 5
    }

    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    # 非管理员尝试审批
    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@participant1)
    assert_response :forbidden

    # 测试重复报名
    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    post api_v1_event_enrollments_path(event_id), headers: authenticate_user(@participant1)
    assert_response :success

    post api_v1_event_enrollments_path(event_id), headers: authenticate_user(@participant1)
    assert_response :unprocessable_entity

    # 测试不存在的资源
    get api_v1_reading_event_path(99999), headers: authenticate_user(@admin)
    assert_response :not_found

    # 测试删除不存在的数据
    delete api_v1_event_enrollment_path(event_id, 99999), headers: authenticate_user(@participant1)
    assert_response :not_found
  end

  private

  def create_test_user(role = :user, **attributes)
    default_attrs = {
      wx_openid: "test_openid_#{SecureRandom.hex(4)}",
      nickname: "测试用户#{SecureRandom.hex(4)}",
      avatar_url: "https://example.com/avatar.jpg",
      created_at: Time.current,
      updated_at: Time.current
    }

    case role
    when :admin
      default_attrs[:role] = 1
    when :root
      default_attrs[:role] = 2
    else
      default_attrs[:role] = 0
    end

    User.create!(default_attrs.merge(attributes))
  end

  def authenticate_user(user)
    token = user.generate_jwt_token
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end
end