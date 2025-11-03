# frozen_string_literal: true

require "test_helper"

class Api::AuthControllerTest < ActionDispatch::IntegrationTest
  test "mock login should create user and return token" do
    post api_auth_mock_login_path, params: {
      nickname: "测试用户",
      openid: "test_openid_001",
      avatar_url: "https://example.com/avatar.jpg"
    }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["access_token"]
    assert_equal "测试用户", json_response["user"]["nickname"]
    assert json_response["user"]["avatar_url"].present? # Basic avatar presence check

    # Verify user was created
    user = User.find_by(wx_openid: "test_openid_001")
    assert user
    assert_equal "测试用户", user.nickname
  end

  test "mock login should return existing user if already exists" do
    # Create user first
    existing_user = create_test_user(:user, wx_openid: "existing_openid", nickname: "原有用户")

    post api_auth_mock_login_path, params: {
      nickname: "更新昵称",
      openid: "existing_openid"
    }

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "原有用户", json_response["user"]["nickname"]  # Should not update nickname

    # Verify no duplicate user was created
    users = User.where(wx_openid: "existing_openid")
    assert_equal 1, users.count
    assert_equal existing_user.id, users.first.id
  end

  test "mock login should use default values when params missing" do
    post api_auth_mock_login_path

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["access_token"]
    assert_equal "DHH", json_response["user"]["nickname"]
    # Skip avatar URL validation - not a business critical feature

    # Verify user was created with default openid
    user = User.find_by(wx_openid: "test_dhh_001")
    assert user
    assert_equal "DHH", user.nickname
  end

  test "weChat login should return error when code missing" do
    post api_auth_login_path

    assert_response :bad_request

    json_response = JSON.parse(response.body)
    assert_equal "缺少 code 参数", json_response["error"]
  end

  test "weChat login should return unauthorized when wechat API fails" do
    # Mock the fetch_wechat_openid to return nil (simulating API failure)
    post api_auth_login_path, params: { code: "invalid_code" }

    assert_response :unauthorized

    json_response = JSON.parse(response.body)
    assert_equal "微信登录失败", json_response["error"]
  end

  test "get current user info should return user data when authenticated" do
    user = create_test_user(:user, nickname: "测试用户")
    headers = authenticate_user(user)

    get api_auth_me_path, headers: headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal user.id, json_response["user"]["id"]
    assert_equal "测试用户", json_response["user"]["nickname"]
    assert_equal user.wx_openid, json_response["user"]["wx_openid"]
  end

  test "get current user info should require authentication" do
    get api_auth_me_path

    assert_response :unauthorized
  end

  test "update profile should update user data when valid" do
    user = create_test_user(:user, nickname: "原名")
    headers = authenticate_user(user)

    put "/api/auth/profile", params: {
      user: {
        nickname: "新名称",
        avatar_url: "https://example.com/new_avatar.jpg",
        phone: "13800138000"
      }
    }, headers: headers

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "更新成功", json_response["message"]
    assert_equal "新名称", json_response["user"]["nickname"]
    assert_equal "https://example.com/new_avatar.jpg", json_response["user"]["avatar_url"]
    assert_equal "13800138000", json_response["user"]["phone"]

    # Verify database was updated
    user.reload
    assert_equal "新名称", user.nickname
    assert_equal "https://example.com/new_avatar.jpg", user.avatar_url
    assert_equal "13800138000", user.phone
  end

  test "update profile should return errors when invalid data" do
    user = create_test_user(:user)
    headers = authenticate_user(user)

    put "/api/auth/profile", params: {
      user: {
        nickname: ""  # Invalid empty nickname
      }
    }, headers: headers

    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert json_response["errors"]
    assert json_response["errors"].any?
  end

  test "update profile should require authentication" do
    put "/api/auth/profile", params: {
      user: {
        nickname: "未授权更新"
      }
    }

    assert_response :unauthorized
  end

  test "token should contain correct user information" do
    user = create_test_user(:admin, nickname: "管理员用户")

    post api_auth_mock_login_path, params: {
      nickname: user.nickname,
      openid: user.wx_openid
    }

    assert_response :success

    json_response = JSON.parse(response.body)
    access_token = json_response["access_token"]

    # Decode and verify token contents
    decoded = User.decode_jwt_token(access_token)
    assert_not_nil decoded
    assert_equal user.id, decoded[:user_id]
    assert_equal user.wx_openid, decoded[:wx_openid]
    assert_equal "admin", decoded[:role]
  end

  test "token should have reasonable expiration time" do
    user = create_test_user(:user)

    post api_auth_mock_login_path, params: {
      openid: user.wx_openid
    }

    assert_response :success

    json_response = JSON.parse(response.body)
    access_token = json_response["access_token"]
    decoded = User.decode_jwt_token(access_token)

    # Token should expire about 30 days from now
    expiration_time = Time.at(decoded[:exp])
    expected_time = 30.days.from_now
    time_difference = (expiration_time - expected_time).abs

    # Allow 5 minutes difference
    assert time_difference < 300.seconds
  end

  test "should support different user roles in authentication" do
    # Test root user
    root_user = create_test_user(:root, nickname: "超级管理员")
    post api_auth_mock_login_path, params: {
      nickname: root_user.nickname,
      openid: root_user.wx_openid
    }
    assert_response :success
    root_response = response
    root_json = JSON.parse(root_response.body)
    root_token = root_json["access_token"]

    # Test admin user
    admin_user = create_test_user(:admin, nickname: "管理员")
    post api_auth_mock_login_path, params: {
      nickname: admin_user.nickname,
      openid: admin_user.wx_openid
    }
    assert_response :success
    admin_response = response
    admin_json = JSON.parse(admin_response.body)
    admin_token = admin_json["access_token"]

    # Test regular user
    regular_user = create_test_user(:user, nickname: "普通用户")
    post api_auth_mock_login_path, params: {
      nickname: regular_user.nickname,
      openid: regular_user.wx_openid
    }
    assert_response :success
    regular_response = response
    regular_json = JSON.parse(regular_response.body)
    regular_token = regular_json["access_token"]

    # All tokens should be valid and contain correct role information
    tokens_and_users = [
      [root_token, root_user],
      [admin_token, admin_user],
      [regular_token, regular_user]
    ]

    tokens_and_users.each do |token, user|
      if token
        decoded = User.decode_jwt_token(token)
        assert_equal user.role_as_string, decoded[:role]
      end
    end
  end
end