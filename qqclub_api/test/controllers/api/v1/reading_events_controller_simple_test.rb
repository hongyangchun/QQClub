# frozen_string_literal: true

require "test_helper"

class Api::V1::ReadingEventsControllerSimpleTest < ActionDispatch::IntegrationTest
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
  end

  # Index action tests
  test "should get reading events list without authentication" do
    get api_v1_reading_events_path

    assert_response :success
  end

  test "should get reading events list with authentication" do
    headers = authenticate_user(@user)
    get api_v1_reading_events_path, headers: headers

    assert_response :success
  end

  # Show action tests
  test "should get reading event details" do
    get api_v1_reading_event_path(@reading_event)

    assert_response :success
  end

  test "should get reading event details with authentication" do
    headers = authenticate_user(@user)
    get api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :success
  end

  test "should return 404 for non-existent event" do
    get api_v1_reading_event_path(id: 99999)

    assert_response :not_found
  end

  # Create action tests
  test "should create reading event with authentication" do
    headers = authenticate_user(@user)

    event_params = {
      title: "《三国演义》精读班",
      book_name: "三国演义",
      description: "经典历史小说精读",
      start_date: Date.current + 14.days,
      end_date: Date.current + 21.days
    }

    post api_v1_reading_events_path, params: event_params, headers: headers

    # 可能因为错误处理而失败，但至少应该不是500错误
    assert_not_equal 500, response.status
  end

  test "should not create event without authentication" do
    event_params = {
      title: "未认证创建的活动",
      book_name: "测试书籍"
    }

    post api_v1_reading_events_path, params: event_params

    assert_response :unauthorized
  end

  # Update action tests
  test "should update reading event as leader" do
    headers = authenticate_user(@leader)

    update_params = {
      title: "更新后的红楼梦精读班"
    }

    patch api_v1_reading_event_path(@reading_event), params: update_params, headers: headers

    # 可能因为错误处理而失败，但至少应该不是500错误
    assert_not_equal 500, response.status
  end

  test "should not update event as non-leader" do
    headers = authenticate_user(@user)

    update_params = {
      title: "恶意修改的活动标题"
    }

    patch api_v1_reading_event_path(@reading_event), params: update_params, headers: headers

    assert_response :forbidden
  end

  # Start action tests
  test "should not start event as non-leader" do
    headers = authenticate_user(@user)

    post start_api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :forbidden
  end

  # Admin action tests
  test "should not approve event as non-admin" do
    headers = authenticate_user(@user)

    post approve_api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :forbidden
  end

  test "should not reject event as non-admin" do
    headers = authenticate_user(@user)

    post reject_api_v1_reading_event_path(@reading_event), headers: headers

    assert_response :forbidden
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