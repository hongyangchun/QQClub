# frozen_string_literal: true

require "test_helper"

class LeaderAssignmentWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    @creator = create_test_user(:user)
    @admin = create_test_user(:admin)
    @participants = Array.new(8) { create_test_user(:user) }
  end

  # 领读人自愿报名工作流测试
  test "should handle voluntary leadership assignment workflow" do
    # 创建自愿分配领读人的活动
    event_data = build_event_data(leader_assignment_type: "voluntary")
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    # 审批活动
    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 创建阅读计划
    create_reading_schedules(event_id, 5)

    # 用户报名活动
    @participants.take(5).each do |participant|
      result = enroll_user_in_event(participant, event_id)
      assert result[:success]
    end

    # 开始活动
    patch api_v1_reading_event_path(event_id), params: { status: "in_progress" }, headers: authenticate_user(@admin)
    assert_response :success

    # 获取可报名的日程
    get api_v1_available_leadership_schedules_path(event_id), headers: authenticate_user(@participants.first)
    assert_response :success

    schedules_response = JSON.parse(response.body)
    available_schedules = schedules_response["schedules"]
    assert_equal 5, available_schedules.length

    # 参与者自愿报名领读
    leader_assignments = []
    available_schedules.take(3).each_with_index do |schedule, index|
      participant = @participants[index + 1]
      assignment_data = {
        reading_schedule_id: schedule["id"],
        user_id: participant.id
      }

      post api_v1_claim_leadership_path(event_id), params: assignment_data, headers: authenticate_user(participant)
      assert_response :success

      leader_assignments << {
        schedule_id: schedule["id"],
        leader_id: participant.id,
        day_number: schedule["day_number"]
      }
    end

    # 验证领读人分配
    leader_assignments.each do |assignment|
      schedule = ReadingSchedule.find(assignment[:schedule_id])
      assert_equal assignment[:leader_id], schedule.daily_leader_id
    end

    # 测试重复报名限制
    duplicate_assignment_data = {
      reading_schedule_id: leader_assignments.first[:schedule_id],
      user_id: @participants.last.id
    }

    post api_v1_claim_leadership_path(event_id), params: duplicate_assignment_data, headers: authenticate_user(@participants.last)
    assert_response :unprocessable_entity

    error_response = JSON.parse(response.body)
    assert_includes error_response["error"], "该日已有领读人"

    # 测试个人领读次数限制
    schedule = ReadingSchedule.where(reading_event_id: event_id).where(daily_leader: nil).first
    if schedule
      # 已有3次领读的参与者再次报名
      over_limit_data = {
        reading_schedule_id: schedule.id,
        user_id: leader_assignments.first[:leader_id]
      }

      post api_v1_claim_leadership_path(event_id), params: over_limit_data, headers: authenticate_user(User.find(leader_assignments.first[:leader_id]))
      assert_response :unprocessable_entity

      error_response = JSON.parse(response.body)
      assert_includes error_response["error"], "领读次数已达上限"
    end
  end

  # 领读人随机分配工作流测试
  test "should handle random leadership assignment workflow" do
    # 创建随机分配领读人的活动
    event_data = build_event_data(leader_assignment_type: "random")
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    # 审批活动
    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 创建阅读计划
    create_reading_schedules(event_id, 6)

    # 用户报名活动
    @participants.take(6).each do |participant|
      result = enroll_user_in_event(participant, event_id)
      assert result[:success]
    end

    # 自动分配领读人
    post api_v1_auto_assign_leaders_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    assignment_response = JSON.parse(response.body)
    assert_equal "random", assignment_response["assignment_type"]
    assert_equal 6, assignment_response["assigned_count"]

    # 验证分配结果
    schedules = ReadingSchedule.where(reading_event_id: event_id).includes(:daily_leader)
    assigned_leaders = schedules.pluck(:daily_leader_id).compact

    assert_equal 6, assigned_leaders.length
    assert assigned_leaders.all? { |leader_id| @participants.map(&:id).include?(leader_id) }

    # 验证分配的公平性（每个参与者至少有一次领读机会）
    leader_counts = assigned_leaders.group_by(&:itself).transform_values(&:count)
    max_count = leader_counts.values.max
    min_count = leader_counts.values.min

    assert max_count - min_count <= 1, "领读人分配应该尽量均衡"
  end

  # 领读人平衡分配工作流测试
  test "should handle balanced leadership assignment workflow" do
    # 创建平衡分配领读人的活动
    event_data = build_event_data(leader_assignment_type: "balanced")
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    # 审批活动
    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 创建阅读计划
    create_reading_schedules(event_id, 8)

    # 用户报名活动（包含有历史领读经验的用户）
    @participants.take(4).each do |participant|
      result = enroll_user_in_event(participant, event_id)
      assert result[:success]
    end

    # 模拟历史领读记录（通过设置不同的权重）
    # 这里通过数据库记录来模拟历史工作量
    leader_weights = {
      @participants[0].id => 0,  # 无经验
      @participants[1].id => 1,  # 1次经验
      @participants[2].id => 2,  # 2次经验
      @participants[3].id => 0   # 无经验
    }

    # 平衡分配领读人
    post api_v1_auto_assign_leaders_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    assignment_response = JSON.parse(response.body)
    assert_equal "balanced", assignment_response["assignment_type"]
    assert_equal 8, assignment_response["assigned_count"]

    # 验证分配结果
    schedules = ReadingSchedule.where(reading_event_id: event_id).includes(:daily_leader)
    leader_assignments = schedules.pluck(:daily_leader_id).compact

    # 经验较少的用户应该获得更多机会
    assignment_counts = leader_assignments.group_by(&:itself).transform_values(&:count)

    # 验证无经验用户获得了合理的机会
    new_leaders = [@participants[0].id, @participants[3].id]
    new_leader_assignments = assignment_counts.select { |leader_id, _| new_leaders.include?(leader_id) }

    assert new_leader_assignments.values.sum >= 4, "新领读人应该获得足够的领读机会"
  end

  # 领读人轮换分配工作流测试
  test "should handle rotation leadership assignment workflow" do
    # 创建轮换分配领读人的活动
    event_data = build_event_data(leader_assignment_type: "rotation")
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    # 审批活动
    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 创建阅读计划
    create_reading_schedules(event_id, 6)

    # 用户报名活动
    @participants.take(4).each do |participant|
      result = enroll_user_in_event(participant, event_id)
      assert result[:success]
    end

    # 轮换分配领读人
    post api_v1_auto_assign_leaders_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    assignment_response = JSON.parse(response.body)
    assert_equal "rotation", assignment_response["assignment_type"]
    assert_equal 6, assignment_response["assigned_count"]

    # 验证轮换分配结果
    schedules = ReadingSchedule.where(reading_event_id: event_id).order(:day_number).includes(:daily_leader)
    leader_sequence = schedules.pluck(:daily_leader_id)

    # 验证没有连续两天是同一个领读人
    leader_sequence.each_cons(2) do |leader1, leader2|
      assert_not_equal leader1, leader2, "轮换分配应该避免连续两天同一人领读"
    end

    # 验证所有参与者都有机会
    unique_leaders = leader_sequence.uniq
    assert_equal 4, unique_leaders.length
    assert unique_leaders.all? { |leader_id| @participants.take(4).map(&:id).include?(leader_id) }
  end

  # 领读人补位工作流测试
  test "should handle leader backup and replacement workflow" do
    # 创建活动
    event_data = build_event_data(leader_assignment_type: "voluntary")
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    # 审批活动
    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 创建阅读计划
    create_reading_schedules(event_id, 3)

    # 用户报名
    @participants.take(3).each do |participant|
      result = enroll_user_in_event(participant, event_id)
      assert result[:success]
    end

    # 开始活动
    patch api_v1_reading_event_path(event_id), params: { status: "in_progress" }, headers: authenticate_user(@admin)
    assert_response :success

    # 自愿报名领读
    schedules = ReadingSchedule.where(reading_event_id: event_id)
    first_schedule = schedules.first

    assignment_data = {
      reading_schedule_id: first_schedule.id,
      user_id: @participants.first.id
    }

    post api_v1_claim_leadership_path(event_id), params: assignment_data, headers: authenticate_user(@participants.first)
    assert_response :success

    # 验证领读人分配
    first_schedule.reload
    assert_equal @participants.first.id, first_schedule.daily_leader_id

    # 模拟领读人需要补位的情况
    backup_data = {
      reading_schedule_id: first_schedule.id,
      new_leader_id: @creator.id,
      backup_reason: "原领读人临时有事，由活动创建者补位"
    }

    post api_v1_leader_backup_path(event_id), params: backup_data, headers: authenticate_user(@creator)
    assert_response :success

    backup_response = JSON.parse(response.body)
    assert_equal "补位分配成功", backup_response["message"]

    # 验证补位结果
    first_schedule.reload
    assert_equal @creator.id, first_schedule.daily_leader_id

    # 验证补位日志
    get api_v1_leader_assignment_logs_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    logs_response = JSON.parse(response.body)
    assert logs_response["logs"].length >= 1

    backup_log = logs_response["logs"].find { |log| log["action"] == "backup_assignment" }
    assert_not_nil backup_log
    assert_equal @participants.first.id, backup_log["old_leader_id"]
    assert_equal @creator.id, backup_log["new_leader_id"]
  end

  # 领读人统计和监控工作流测试
  test "should handle leadership statistics and monitoring workflow" do
    # 创建活动
    event_data = build_event_data(leader_assignment_type: "voluntary")
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    # 审批活动
    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 创建阅读计划
    create_reading_schedules(event_id, 7)

    # 用户报名
    @participants.take(5).each do |participant|
      result = enroll_user_in_event(participant, event_id)
      assert result[:success]
    end

    # 开始活动
    patch api_v1_reading_event_path(event_id), params: { status: "in_progress" }, headers: authenticate_user(@admin)
    assert_response :success

    # 领读人报名
    schedules = ReadingSchedule.where(reading_event_id: event_id).take(3)
    schedules.each_with_index do |schedule, index|
      participant = @participants[index + 1]
      assignment_data = {
        reading_schedule_id: schedule.id,
        user_id: participant.id
      }

      post api_v1_claim_leadership_path(event_id), params: assignment_data, headers: authenticate_user(participant)
      assert_response :success

      # 模拟发布领读内容
      leading_data = {
        reading_schedule_id: schedule.id,
        content: "第#{index + 1}天的领读内容",
        summary: "第#{index + 1}天的要点总结"
      }

      post api_v1_daily_leading_path, params: leading_data, headers: authenticate_user(participant)
      assert_response :success
    end

    # 获取领读人统计
    get api_v1_leadership_statistics_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    stats_response = JSON.parse(response.body)
    assert stats_response.key?("assignment_summary")
    assert stats_response.key?("leader_workloads")
    assert stats_response.key?("completion_rates")
    assert stats_response.key?("engagement_metrics")

    # 验证统计数据
    assignment_summary = stats_response["assignment_summary"]
    assert_equal 7, assignment_summary["total_schedules"]
    assert_equal 3, assignment_summary["assigned_schedules"]
    assert_equal 4, assignment_summary["unassigned_schedules"]

    leader_workloads = stats_response["leader_workloads"]
    assert_equal 3, leader_workloads.length
    leader_workloads.each do |workload|
      assert workload.key?("user_id")
      assert workload.key?("nickname")
      assert workload.key?("assigned_count")
      assert workload.key?("content_completed")
      assert workload.key?("flowers_received")
    end

    # 获取个人领读统计
    leader_id = @participants[1].id
    get api_v1_user_leadership_stats_path(event_id, leader_id), headers: authenticate_user(@participants[1])
    assert_response :success

    user_stats_response = JSON.parse(response.body)
    assert user_stats_response.key?("assigned_schedules")
    assert user_stats_response.key?("completed_schedules")
    assert user_stats_response.key?("total_flowers")
    assert user_stats_response.key?("completion_rate")
  end

  # 领读人权限管理工作流测试
  test "should handle leadership permission management workflow" do
    # 创建活动
    event_data = build_event_data(leader_assignment_type: "voluntary")
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    # 审批活动
    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 创建阅读计划
    create_reading_schedules(event_id, 3)

    # 用户报名
    @participants.take(3).each do |participant|
      result = enroll_user_in_event(participant, event_id)
      assert result[:success]
    end

    # 开始活动
    patch api_v1_reading_event_path(event_id), params: { status: "in_progress" }, headers: authenticate_user(@admin)
    assert_response :success

    # 领读人报名
    schedule = ReadingSchedule.where(reading_event_id: event_id).first
    assignment_data = {
      reading_schedule_id: schedule.id,
      user_id: @participants.first.id
    }

    post api_v1_claim_leadership_path(event_id), params: assignment_data, headers: authenticate_user(@participants.first)
    assert_response :success

    # 测试领读人权限
    leader_headers = authenticate_user(@participants.first)

    # 领读人可以发布内容
    leading_data = {
      reading_schedule_id: schedule.id,
      content: "领读内容测试",
      summary: "内容摘要"
    }

    post api_v1_daily_leading_path, params: leading_data, headers: leader_headers
    assert_response :success

    # 领读人可以给参与者送花
    flower_data = {
      receiver_id: @participants.second.id,
      reading_schedule_id: schedule.id,
      flower_type: "participation",
      reason: "积极参与讨论"
    }

    post api_v1_flowers_path, params: flower_data, headers: leader_headers
    assert_response :success

    # 非领读人不能发布领读内容
    non_leader_headers = authenticate_user(@participants.second)
    unauthorized_leading_data = {
      reading_schedule_id: schedule.id,
      content: "未授权的领读内容"
    }

    post api_v1_daily_leading_path, params: unauthorized_leading_data, headers: non_leader_headers
    assert_response :forbidden

    # 测试权限窗口（领读人只能在指定时间内操作）
    # 模拟时间窗口外的操作
    schedule.update!(date: Date.current - 2.days)

    old_leading_data = {
      reading_schedule_id: schedule.id,
      content: "过期时间的内容"
    }

    post api_v1_daily_leading_path, params: old_leading_data, headers: leader_headers
    assert_response :forbidden

    error_response = JSON.parse(response.body)
    assert_includes error_response["error"], "权限窗口已关闭"
  end

  private

  def build_event_data(overrides = {})
    default_data = {
      title: "领读人测试活动",
      book_name: "领读艺术",
      description: "专门用于测试领读人分配机制的活动",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 10,
      min_participants: 3,
      fee_type: "free",
      fee_amount: 0,
      leader_reward_percentage: 0,
      completion_standard: 80,
      activity_mode: "note_checkin",
      weekend_rest: true
    }

    default_data.merge(overrides)
  end

  def create_reading_schedules(event_id, days_count)
    days_count.times do |i|
      ReadingSchedule.create!(
        reading_event_id: event_id,
        date: Date.current + 8.days + i.days,
        day_number: i + 1,
        reading_progress: "第#{i + 1}章"
      )
    end
  end

  def enroll_user_in_event(user, event_id)
    headers = authenticate_user(user)

    post api_v1_event_enrollments_path(event_id), headers: headers

    if response.success?
      { success: true, data: JSON.parse(response.body) }
    else
      { success: false, error: JSON.parse(response.body)["error"], status: response.status }
    end
  rescue => e
    { success: false, error: e.message }
  end

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