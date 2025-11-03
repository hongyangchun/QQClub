# frozen_string_literal: true

require "test_helper"

class EnrollmentWorkflowTest < ActionDispatch::IntegrationTest
  def setup
    @creator = create_test_user(:user)
    @admin = create_test_user(:admin)
    @participants = Array.new(10) { create_test_user(:user) }
  end

  # 完整报名流程集成测试
  test "should handle complete enrollment workflow with validation and notifications" do
    # 1. 创建活动
    event_data = build_valid_event_data
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    # 2. 审批活动
    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 3. 设置阅读计划
    create_reading_schedules(event_id, 7)

    # 4. 并发报名测试
    enrollment_results = []
    threads = []

    @participants.take(8).each_with_index do |participant, index|
      threads << Thread.new do
        enrollment_result = enroll_user_in_event(participant, event_id)
        enrollment_results << { user_id: participant.id, result: enrollment_result }
      end
    end

    threads.each(&:join)

    # 5. 验证报名结果
    successful_enrollments = enrollment_results.select { |r| r[:result][:success] }
    failed_enrollments = enrollment_results.select { |r| !r[:result][:success] }

    # 应该有8个成功报名（活动容量为10）
    assert_equal 8, successful_enrollments.length

    # 6. 验证活动状态
    get api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    event_detail = JSON.parse(response.body)
    assert_equal 8, event_detail["current_participants"]
    assert_equal false, event_detail["is_full"]

    # 7. 报名满员测试
    remaining_participants = @participants[8..9]
    remaining_participants.each do |participant|
      result = enroll_user_in_event(participant, event_id)
      assert result[:success]
    end

    # 验证活动已满员
    get api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    event_detail = JSON.parse(response.body)
    assert_equal 10, event_detail["current_participants"]
    assert_equal true, event_detail["is_full"]

    # 8. 超额报名测试
    extra_user = create_test_user(:user)
    result = enroll_user_in_event(extra_user, event_id)
    assert_not result[:success]
    assert_includes result[:error], "活动已满员"
  end

  # 活动状态验证集成测试
  test "should enforce enrollment restrictions based on event status" do
    event_data = build_valid_event_data
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    # 测试未审批活动的报名限制
    result = enroll_user_in_event(@participants.first, event_id)
    assert_not result[:success]
    assert_includes result[:error], "活动尚未审批通过"

    # 审批通过
    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 审批后应该可以报名
    result = enroll_user_in_event(@participants.first, event_id)
    assert result[:success]

    # 将活动设置为进行中状态
    patch api_v1_reading_event_path(event_id), params: { status: "in_progress" }, headers: authenticate_user(@admin)
    assert_response :success

    # 进行中的活动不能报名
    result = enroll_user_in_event(@participants.second, event_id)
    assert_not result[:success]
    assert_includes result[:error], "当前活动不在报名期间"

    # 将活动设置为已完成状态
    patch api_v1_reading_event_path(event_id), params: { status: "completed" }, headers: authenticate_user(@admin)
    assert_response :success

    # 已完成的活动不能报名
    result = enroll_user_in_event(@participants.third, event_id)
    assert_not result[:success]
    assert_includes result[:error], "当前活动不在报名期间"
  end

  # 报名数据一致性集成测试
  test "should maintain data consistency during concurrent enrollments" do
    event_data = build_valid_event_data(max_participants: 5)
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    initial_enrollment_count = EventEnrollment.count

    # 高并发报名
    threads = []
    results = Concurrent::Array.new

    @participants.take(10).each do |participant|
      threads << Thread.new do
        begin
          result = enroll_user_in_event(participant, event_id)
          results << { user_id: participant.id, success: result[:success], thread_id: Thread.current.object_id }
        rescue => e
          results << { user_id: participant.id, success: false, error: e.message, thread_id: Thread.current.object_id }
        end
      end
    end

    threads.each(&:join)

    # 验证数据一致性
    successful_enrollments = results.select { |r| r[:success] }
    assert_equal 5, successful_enrollments.length, "应该只有5个成功报名"

    # 验证数据库中的报名记录数量
    final_enrollment_count = EventEnrollment.count
    assert_equal initial_enrollment_count + 5, final_enrollment_count

    # 验证所有成功的报名都有对应的数据库记录
    successful_enrollments.each do |enrollment|
      user_id = enrollment[:user_id]
      enrollment_record = EventEnrollment.find_by(user_id: user_id, reading_event_id: event_id)
      assert_not_nil enrollment_record, "成功的报名应该有对应的数据库记录"
      assert_equal "enrolled", enrollment_record.status
    end

    # 验证活动统计正确
    get api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    event_detail = JSON.parse(response.body)
    assert_equal 5, event_detail["current_participants"]
  end

  # 报名权限验证集成测试
  test "should enforce enrollment permissions and user validation" do
    event_data = build_valid_event_data
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 测试未认证用户
    post api_v1_event_enrollments_path(event_id)
    assert_response :unauthorized

    # 测试已删除用户的报名
    deleted_user = create_test_user(:user)
    deleted_user.destroy!

    deleted_headers = authenticate_user(deleted_user)
    post api_v1_event_enrollments_path(event_id), headers: deleted_headers
    assert_response :unauthorized

    # 测试重复报名
    result = enroll_user_in_event(@participants.first, event_id)
    assert result[:success]

    result = enroll_user_in_event(@participants.first, event_id)
    assert_not result[:success]
    assert_includes result[:error], "您已经报名该活动"

    # 测试用户报名多个活动的并发情况
    event_data2 = build_valid_event_data(title: "第二个活动")
    post api_v1_reading_events_path, params: event_data2, headers: authenticate_user(@creator)
    assert_response :success

    event_response2 = JSON.parse(response.body)
    event_id2 = event_response2["id"]

    post approve_api_v1_reading_event_path(event_id2), headers: authenticate_user(@admin)
    assert_response :success

    # 用户可以报名多个活动
    result = enroll_user_in_event(@participants.second, event_id)
    assert result[:success]

    result = enroll_user_in_event(@participants.second, event_id2)
    assert result[:success]

    # 验证用户有两个不同的报名记录
    user_enrollments = EventEnrollment.where(user_id: @participants.second.id)
    assert_equal 2, user_enrollments.count
    assert_equal [event_id, event_id2].sort, user_enrollments.pluck(:reading_event_id).sort
  end

  # 报名费用处理集成测试
  test "should handle paid event enrollment workflow correctly" do
    # 创建付费活动
    paid_event_data = build_valid_event_data(
      fee_type: "paid",
      fee_amount: 100,
      leader_reward_percentage: 10
    )
    post api_v1_reading_events_path, params: paid_event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 付费活动报名
    result = enroll_user_in_event(@participants.first, event_id)
    assert result[:success]

    # 验证报名记录包含费用信息
    enrollment = EventEnrollment.find_by(user_id: @participants.first.id, reading_event_id: event_id)
    assert_not_nil enrollment
    assert_equal 100, enrollment.fee_paid_amount
    assert_equal "pending", enrollment.refund_status

    # 测试退款流程
    patch api_v1_event_enrollment_path(event_id, enrollment.id),
          params: { refund_status: "refunded", refund_amount: 100, refund_reason: "用户主动取消" },
          headers: authenticate_user(@admin)
    assert_response :success

    # 验证退款状态
    enrollment.reload
    assert_equal "refunded", enrollment.refund_status
    assert_equal 100, enrollment.fee_refund_amount
  end

  # 报名截止时间处理集成测试
  test "should handle enrollment deadline workflow" do
    # 创建有报名截止时间的活动
    event_data = build_valid_event_data(
      start_date: Date.current + 14.days,
      end_date: Date.current + 28.days,
      enrollment_deadline: Date.current + 7.days
    )
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 在截止时间前应该可以报名
    result = enroll_user_in_event(@participants.first, event_id)
    assert result[:success]

    # 模拟超过截止时间
    event = ReadingEvent.find(event_id)
    event.update!(enrollment_deadline: Date.current - 1.day)

    # 超过截止时间不能报名
    result = enroll_user_in_event(@participants.second, event_id)
    assert_not result[:success]
    assert_includes result[:error], "报名已截止"

    # 验证活动状态
    get api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    event_detail = JSON.parse(response.body)
    assert_equal true, event_detail["enrollment_closed"]
  end

  # 报名列表和分页集成测试
  test "should handle enrollment list and pagination correctly" do
    event_data = build_valid_event_data(max_participants: 20)
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 批量报名
    @participants.take(15).each do |participant|
      result = enroll_user_in_event(participant, event_id)
      assert result[:success]
    end

    # 获取报名列表（第一页）
    get api_v1_event_enrollments_path(event_id), params: { page: 1, per_page: 5 }, headers: authenticate_user(@admin)
    assert_response :success

    enrollments_response = JSON.parse(response.body)
    assert_equal 5, enrollments_response["enrollments"].length
    assert_equal 15, enrollments_response["pagination"]["total_count"]
    assert_equal 3, enrollments_response["pagination"]["total_pages"]
    assert_equal 1, enrollments_response["pagination"]["current_page"]

    # 获取第二页
    get api_v1_event_enrollments_path(event_id), params: { page: 2, per_page: 5 }, headers: authenticate_user(@admin)
    assert_response :success

    enrollments_response = JSON.parse(response.body)
    assert_equal 5, enrollments_response["enrollments"].length

    # 测试搜索和过滤
    get api_v1_event_enrollments_path(event_id), params: { search: @participants.first.nickname }, headers: authenticate_user(@admin)
    assert_response :success

    search_response = JSON.parse(response.body)
    assert search_response["enrollments"].length >= 1
    assert search_response["enrollments"].first["nickname"].include?(@participants.first.nickname)
  end

  # 报名数据导出集成测试
  test "should handle enrollment data export correctly" do
    event_data = build_valid_event_data(max_participants: 10)
    post api_v1_reading_events_path, params: event_data, headers: authenticate_user(@creator)
    assert_response :success

    event_response = JSON.parse(response.body)
    event_id = event_response["id"]

    post approve_api_v1_reading_event_path(event_id), headers: authenticate_user(@admin)
    assert_response :success

    # 添加一些报名数据
    @participants.take(5).each do |participant|
      result = enroll_user_in_event(participant, event_id)
      assert result[:success]
    end

    # 导出CSV格式
    get api_v1_event_enrollments_export_path(event_id, format: :csv), headers: authenticate_user(@admin)
    assert_response :success
    assert_equal "text/csv", response.content_type

    # 导出Excel格式
    get api_v1_event_enrollments_export_path(event_id, format: :xlsx), headers: authenticate_user(@admin)
    assert_response :success

    # 验证导出数据包含必要字段
    csv_content = response.body
    assert_includes csv_content, "用户昵称"
    assert_includes csv_content, "报名时间"
    assert_includes csv_content, "费用状态"
  end

  private

  def build_valid_event_data(overrides = {})
    default_data = {
      title: "测试读书活动",
      book_name: "测试书籍",
      description: "这是一个详细的读书活动描述，包含活动目标、内容和安排。",
      start_date: Date.current + 14.days,
      end_date: Date.current + 28.days,
      max_participants: 10,
      min_participants: 3,
      fee_type: "free",
      fee_amount: 0,
      leader_reward_percentage: 0,
      completion_standard: 80,
      activity_mode: "note_checkin",
      leader_assignment_type: "voluntary",
      weekend_rest: true
    }

    default_data.merge(overrides)
  end

  def create_reading_schedules(event_id, days_count)
    days_count.times do |i|
      ReadingSchedule.create!(
        reading_event_id: event_id,
        date: Date.current + 14.days + i.days,
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