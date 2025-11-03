# frozen_string_literal: true

require "test_helper"

class Api::V1::ReadingEventsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_test_user(:user)
    @admin = create_test_user(:admin)
    @leader = create_test_user(:user)

    # 创建测试活动
    @reading_event = ReadingEvent.create!(
      title: "《红楼梦》精读班",
      book_name: "红楼梦",
      description: "一起精读中国古典名著红楼梦",
      start_date: Date.current + 7.days,
      end_date: Date.current + 14.days,
      max_participants: 20,
      min_participants: 5,
      fee_type: "free",
      fee_amount: 0,
      leader_reward_percentage: 0,
      completion_standard: 80,
      activity_mode: "note_checkin",
      leader_assignment_type: "voluntary",
      weekend_rest: true,
      leader: @leader
    )

    # 创建另一个活动用于列表测试
    @other_event = ReadingEvent.create!(
      title: "《西游记》读书会",
      book_name: "西游记",
      description: "经典神话小说阅读",
      start_date: Date.current + 21.days,
      end_date: Date.current + 28.days,
      max_participants: 15,
      min_participants: 3,
      fee_type: "deposit",
      fee_amount: 50,
      leader: @admin
    )

    # 创建用户报名记录
    @enrollment = EventEnrollment.create!(
      user: @user,
      reading_event: @reading_event,
      status: "enrolled",
      enrollment_date: Time.current
    )
  end

  # Index action tests
  test "should get reading events list without authentication" do
    get api_v1_reading_events_path

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert json_response["data"].is_a?(Array)
    assert json_response["meta"].present?

    # 应该返回两个活动
    assert_equal 2, json_response["data"].length

    # 验证返回的数据结构
    event_data = json_response["data"].first
    assert event_data["id"]
    assert event_data["title"]
    assert event_data["book_name"]
    assert event_data["status"]
    assert event_data["participants_count"]
    assert event_data["leader"]["id"]
    assert event_data["leader"]["nickname"]
  end

  test "should filter reading events by status" do
    @reading_event.update!(status: :enrolling)

    get api_v1_reading_events_path, params: { status: "enrolling" }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert_equal "enrolling", json_response["data"].first["status"]
  end

  test "should filter reading events by activity mode" do
    get api_v1_reading_events_path, params: { activity_mode: "note_checkin" }

    assert_response :success

    json_response = JSON.parse(response.body)
    # 两个活动都是note_checkin模式
    assert_equal 2, json_response["data"].length
    json_response["data"].each do |event|
      assert_equal "note_checkin", event["activity_mode"]
    end
  end

  test "should filter reading events by fee type" do
    get api_v1_reading_events_path, params: { fee_type: "free" }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert_equal "free", json_response["data"].first["fee_type"]
  end

  test "should search reading events by keyword" do
    get api_v1_reading_events_path, params: { keyword: "红楼梦" }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert_includes json_response["data"].first["title"], "红楼梦"
  end

  test "should filter reading events by date range" do
    get api_v1_reading_events_path, params: {
      start_date_from: Date.current + 10.days,
      start_date_to: Date.current + 25.days
    }

    assert_response :success

    json_response = JSON.parse(response.body)
    # 应该只返回第二个活动（西游记）
    assert_equal 1, json_response["data"].length
    assert_includes json_response["data"].first["title"], "西游记"
  end

  test "should sort reading events" do
    get api_v1_reading_events_path, params: { sort: "title", direction: "asc" }

    assert_response :success

    json_response = JSON.parse(response.body)
    titles = json_response["data"].map { |e| e["title"] }
    assert_equal titles.sort, titles
  end

  test "should paginate reading events" do
    get api_v1_reading_events_path, params: { page: 1, per_page: 1 }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 1, json_response["data"].length
    assert_equal 1, json_response["meta"]["current_page"]
    assert_equal 2, json_response["meta"]["total_pages"]
    assert_equal 2, json_response["meta"]["total_count"]
  end

  # Show action tests
  test "should get reading event details without authentication" do
    get api_v1_reading_event_path(@reading_event)

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]

    event_data = json_response["data"]
    assert_equal @reading_event.id, event_data["id"]
    assert_equal @reading_event.title, event_data["title"]
    assert_equal @reading_event.book_name, event_data["book_name"]
    assert_equal @reading_event.description, event_data["description"]
    assert_equal @reading_event.activity_mode, event_data["activity_mode"]
    assert_equal @reading_event.fee_type, event_data["fee_type"]
    assert_equal @reading_event.days_count, event_data["days_count"]
    assert_equal @reading_event.participants_count, event_data["participants_count"]
    assert_equal @reading_event.available_spots, event_data["available_spots"]
  end

  test "should include user enrollment info when authenticated" do
    headers = authenticate_user(@user)

    get api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :success

    json_response = JSON.parse(response.body)
    event_data = json_response["data"]

    # 应该包含用户报名信息
    assert event_data["user_enrollment"].present?
    assert_equal @enrollment.id, event_data["user_enrollment"]["id"]
    assert_equal "enrolled", event_data["user_enrollment"]["status"]

    # 应该包含用户权限信息
    assert event_data["user_permissions"].present?
    assert event_data["user_permissions"]["can_enroll"].is_a?(TrueClass) || event_data["user_permissions"]["can_enroll"].is_a?(FalseClass)
    assert_equal false, event_data["user_permissions"]["can_edit"] # 不是创建者
    assert_equal false, event_data["user_permissions"]["can_start"] # 不是创建者
  end

  test "should return correct permissions for event leader" do
    headers = authenticate_user(@leader)

    get api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :success

    json_response = JSON.parse(response.body)
    event_data = json_response["data"]

    # 创建者应该有编辑权限
    assert_equal true, event_data["user_permissions"]["can_edit"]
    assert event_data["user_permissions"]["can_start"].is_a?(TrueClass) || event_data["user_permissions"]["can_start"].is_a?(FalseClass)
  end

  test "should return 404 for non-existent event" do
    get api_v1_reading_event_path(id: 99999)

    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_equal "活动不存在", json_response["message"]
    assert_equal "EVENT_NOT_FOUND", json_response["code"]
  end

  # Create action tests
  test "should create reading event with authentication" do
    headers = authenticate_user(@user)

    event_params = {
      title: "《三国演义》精读班",
      book_name: "三国演义",
      description: "经典历史小说精读",
      start_date: Date.current + 14.days,
      end_date: Date.current + 21.days,
      max_participants: 25,
      min_participants: 8,
      fee_type: "paid",
      fee_amount: 100,
      activity_mode: "free_discussion"
    }

    post api_v1_reading_events_path, params: event_params, headers: headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "活动创建成功", json_response["message"]

    event_data = json_response["data"]
    assert_equal "《三国演义》精读班", event_data["title"]
    assert_equal "三国演义", event_data["book_name"]
    assert_equal "draft", event_data["status"] # 新建活动默认为草稿状态
    assert_equal @user.id, event_data["leader"]["id"]
  end

  test "should not create event without authentication" do
    event_params = {
      title: "未认证创建的活动",
      book_name: "测试书籍",
      start_date: Date.current + 14.days,
      end_date: Date.current + 21.days
    }

    post api_v1_reading_events_path, params: event_params

    assert_response :unauthorized

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_equal "请先登录", json_response["message"]
  end

  test "should return validation errors for invalid event data" do
    headers = authenticate_user(@user)

    # 缺少必要字段
    invalid_params = {
      title: "",
      book_name: "",
      start_date: "",
      end_date: ""
    }

    post api_v1_reading_events_path, params: invalid_params, headers: headers

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_equal "活动创建失败", json_response["message"]
    assert_equal "VALIDATION_ERROR", json_response["code"]
    assert json_response["errors"].present?
  end

  # Update action tests
  test "should update reading event as leader" do
    headers = authenticate_user(@leader)

    update_params = {
      title: "更新后的红楼梦精读班",
      description: "更新后的描述",
      max_participants: 30
    }

    patch api_v1_reading_event_path(@reading_event), params: update_params, headers: headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "活动更新成功", json_response["message"]

    event_data = json_response["data"]
    assert_equal "更新后的红楼梦精读班", event_data["title"]
    assert_equal "更新后的描述", event_data["description"]
    assert_equal 30, event_data["max_participants"]
  end

  test "should not update event as non-leader" do
    headers = authenticate_user(@user)

    update_params = {
      title: "恶意修改的活动标题"
    }

    patch api_v1_reading_event_path(@reading_event), params: update_params, headers: headers

    assert_response :forbidden

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["message"], "权限不足"
  end

  test "should not update event without authentication" do
    update_params = {
      title: "未认证修改的活动"
    }

    patch api_v1_reading_event_path(@reading_event), params: update_params

    assert_response :unauthorized
  end

  # Destroy action tests
  test "should delete draft event as leader" do
    # 确保活动是草稿状态
    @reading_event.update!(status: :draft)

    headers = authenticate_user(@leader)

    delete api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "活动删除成功", json_response["message"]

    # 验证活动已被删除
    assert_not ReadingEvent.exists?(@reading_event.id)
  end

  test "should delete rejected event as leader" do
    # 设置活动为被拒绝状态
    @reading_event.reject!(@admin, "测试拒绝")

    headers = authenticate_user(@leader)

    delete api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]

    # 验证活动已被删除
    assert_not ReadingEvent.exists?(@reading_event.id)
  end

  test "should not delete active event" do
    # 设置活动为进行中状态
    @reading_event.update!(status: :in_progress)

    headers = authenticate_user(@leader)

    delete api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_equal "只有草稿状态或被拒绝的活动才能删除", json_response["message"]
    assert_equal "CANNOT_DELETE_EVENT", json_response["code"]

    # 验证活动仍然存在
    assert ReadingEvent.exists?(@reading_event.id)
  end

  test "should not delete event as non-leader" do
    headers = authenticate_user(@user)

    delete api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :forbidden

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["message"], "权限不足"
  end

  # Start action tests
  test "should start event as leader when conditions are met" do
    # 设置活动状态为报名中并已批准
    @reading_event.update!(
      status: :enrolling,
      approval_status: :approved,
      start_date: Date.current,
      min_participants: 1
    )

    headers = authenticate_user(@leader)

    post start_api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "活动已开始", json_response["message"]

    # 验证活动状态已更新
    @reading_event.reload
    assert_equal "in_progress", @reading_event.status
  end

  test "should not start event when conditions are not met" do
    # 活动未达到最少人数要求
    @reading_event.update!(
      status: :enrolling,
      approval_status: :approved,
      start_date: Date.current,
      min_participants: 10
    )

    headers = authenticate_user(@leader)

    post start_api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_equal "活动当前状态无法开始", json_response["message"]
    assert_equal "CANNOT_START_EVENT", json_response["code"]
  end

  test "should not start event as non-leader" do
    headers = authenticate_user(@user)

    post start_api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :forbidden
  end

  # Complete action tests
  test "should complete event when conditions are met" do
    # 设置活动为进行中状态且已结束
    @reading_event.update!(
      status: :in_progress,
      start_date: Date.current - 14.days,
      end_date: Date.current - 1.day
    )

    headers = authenticate_user(@leader)

    post complete_api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "活动已完成", json_response["message"]

    # 验证活动状态已更新
    @reading_event.reload
    assert_equal "completed", @reading_event.status
  end

  test "should not complete event when conditions are not met" do
    # 活动尚未结束
    @reading_event.update!(
      status: :in_progress,
      end_date: Date.current + 1.day
    )

    headers = authenticate_user(@leader)

    post complete_api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_equal "活动当前状态无法完成", json_response["message"]
    assert_equal "CANNOT_COMPLETE_EVENT", json_response["code"]
  end

  # Approve action tests (admin only)
  test "should approve event as admin" do
    # 设置活动为待审批状态
    @reading_event.update!(approval_status: :pending)

    headers = authenticate_user(@admin)

    post approve_api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "活动已审批通过", json_response["message"]

    # 验证审批状态已更新
    @reading_event.reload
    assert_equal "approved", @reading_event.approval_status
    assert_equal @admin.id, @reading_event.approved_by_id
  end

  test "should not approve event as non-admin" do
    headers = authenticate_user(@user)

    post approve_api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :forbidden

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_includes json_response["message"], "权限不足"
  end

  test "should not approve already approved event" do
    @reading_event.update!(approval_status: :approved)

    headers = authenticate_user(@admin)

    post approve_api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_equal "活动当前状态无法审批", json_response["message"]
  end

  # Reject action tests (admin only)
  test "should reject event as admin" do
    @reading_event.update!(approval_status: :pending)

    headers = authenticate_user(@admin)

    post reject_api_v1_reading_event_path(@reading_event), params: {
      reason: "内容不符合规范"
    }, headers: headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
    assert_equal "活动已拒绝", json_response["message"]

    # 验证拒绝状态已更新
    @reading_event.reload
    assert_equal "rejected", @reading_event.approval_status
    assert_equal "内容不符合规范", @reading_event.rejection_reason
  end

  test "should reject event with default reason as admin" do
    @reading_event.update!(approval_status: :pending)

    headers = authenticate_user(@admin)

    post reject_api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]

    # 验证使用了默认拒绝原因
    @reading_event.reload
    assert_equal "rejected", @reading_event.approval_status
    assert_equal "不符合活动规范", @reading_event.rejection_reason
  end

  # Statistics action tests
  test "should get event statistics when event is in progress" do
    # 设置活动为进行中状态
    @reading_event.update!(status: :in_progress)

    get statistics_api_v1_reading_event_path(@reading_event)

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]

    stats = json_response["data"]
    assert stats["total_participants"].present?
    assert stats["completed_participants"].present?
    assert stats["average_completion_rate"].present?
    assert stats["total_check_ins"].present?
    assert stats["total_flowers"].present?
    assert stats["completion_rate"].present?
    assert stats["top_participants"].is_a?(Array)
  end

  test "should not return statistics for non-started event" do
    # 活动还是草稿状态
    get statistics_api_v1_reading_event_path(@reading_event)

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert_not json_response["success"]
    assert_equal "活动未开始或已结束，暂无统计数据", json_response["message"]
    assert_equal "NO_STATISTICS_AVAILABLE", json_response["code"]
  end

  test "should include top participants in statistics" do
    # 创建多个不同完成率的报名
    high_completion_enrollment = EventEnrollment.create!(
      user: create_test_user(:user),
      reading_event: @reading_event,
      status: "completed",
      enrollment_date: Time.current,
      completion_rate: 95,
      check_ins_count: 10,
      flowers_received_count: 8
    )

    medium_completion_enrollment = EventEnrollment.create!(
      user: create_test_user(:user),
      reading_event: @reading_event,
      status: "enrolled",
      enrollment_date: Time.current,
      completion_rate: 75,
      check_ins_count: 8,
      flowers_received_count: 5
    )

    @reading_event.update!(status: :in_progress)

    get statistics_api_v1_reading_event_path(@reading_event)

    assert_response :success

    json_response = JSON.parse(response.body)
    stats = json_response["data"]

    # 应该包含排行榜
    assert stats["top_participants"].present?
    assert stats["top_participants"].is_a?(Array)

    # 排行榜应该按完成率降序排列
    top_participant = stats["top_participants"].first
    assert_equal high_completion_enrollment.user.id, top_participant["user_id"]
    assert_equal 95, top_participant["completion_rate"]
  end

  # Edge cases and error handling tests
  test "should handle malformed date parameters gracefully" do
    get api_v1_reading_events_path, params: {
      start_date_from: "invalid-date",
      start_date_to: "also-invalid"
    }

    # 应该仍然返回成功，但忽略无效的日期参数
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
  end

  test "should handle very large per_page parameter" do
    get api_v1_reading_events_path, params: { per_page: 1000 }

    assert_response :success

    json_response = JSON.parse(response.body)
    # 应该被限制在最大值100
    assert json_response["meta"]["per_page"] <= 100
  end

  test "should handle negative page parameter" do
    get api_v1_reading_events_path, params: { page: -1 }

    assert_response :success

    json_response = JSON.parse(response.body)
    # 应该使用默认值1
    assert_equal 1, json_response["meta"]["current_page"]
  end

  test "should handle concurrent event creation" do
    headers = authenticate_user(@user)

    # 模拟并发创建请求
    threads = []
    results = []

    3.times do |i|
      threads << Thread.new do
        event_params = {
          title: "并发测试活动 #{i}",
          book_name: "测试书籍 #{i}",
          start_date: Date.current + (i + 10).days,
          end_date: Date.current + (i + 17).days
        }

        post api_v1_reading_events_path, params: event_params, headers: headers
        results << response.status
      end
    end

    threads.each(&:join)

    # 所有请求都应该成功
    results.each do |status|
      assert_equal 200, status
    end
  end

  test "should handle invalid sort field" do
    get api_v1_reading_events_path, params: { sort: "invalid_field" }

    # 应该回退到默认排序
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["success"]
  end

  test "should preserve data integrity during concurrent updates" do
    headers = authenticate_user(@leader)

    original_title = @reading_event.title

    # 模拟并发更新
    threads = []

    threads << Thread.new do
      patch api_v1_reading_event_path(@reading_event),
            params: { title: "并发更新1" },
            headers: headers
    end

    threads << Thread.new do
      patch api_v1_reading_event_path(@reading_event),
            params: { description: "并发更新描述" },
            headers: headers
    end

    threads.each(&:join)

    # 验证数据完整性
    @reading_event.reload
    assert @reading_event.title.present?
    assert @reading_event.description.present?
    # 标题应该被更新为其中一个并发更新的值
    assert_includes ["并发更新1", original_title], @reading_event.title
  end

  # Performance tests
  test "should handle large dataset efficiently" do
    # 创建大量活动
    events = []
    50.times do |i|
      events << ReadingEvent.create!(
        title: "测试活动 #{i}",
        book_name: "测试书籍 #{i}",
        start_date: Date.current + (i + 1).days,
        end_date: Date.current + (i + 8).days,
        max_participants: 20,
        min_participants: 5,
        leader: @leader
      )
    end

    start_time = Time.current

    get api_v1_reading_events_path

    end_time = Time.current
    response_time = end_time - start_time

    # 响应时间应该在合理范围内（小于1秒）
    assert response_time < 1.0
    assert_response :success

    json_response = JSON.parse(response.body)
    # 应该返回所有活动
    assert json_response["meta"]["total_count"] >= 50

    # 清理测试数据
    events.each(&:destroy)
  end

  private

  def authenticate_user(user)
    token = user.generate_jwt_token
    {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  end
end