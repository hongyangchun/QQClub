# frozen_string_literal: true

require "test_helper"

class AuthenticationServiceTest < ActiveSupport::TestCase
  def setup
    @nickname = "测试用户"
    @openid = "test_openid_12345"
    @avatar_url = "https://example.com/avatar.jpg"
  end

  # 模拟登录测试
  test "should mock login successfully with valid params" do
    params = {
      nickname: @nickname,
      openid: @openid,
      avatar_url: @avatar_url
    }

    service = AuthenticationService.new(login_params: params, login_type: :mock)
    result = service.call

    assert result.success?
    assert result.result[:token]
    assert_equal @nickname, result.result[:user]["nickname"]
    assert_equal @avatar_url, result.result[:user]["avatar_url"]

    # 验证用户已创建并包含正确的openid
    user = User.find_by(wx_openid: @openid)
    assert user
    assert_equal @nickname, user.nickname
  end

  test "should mock login with nested user params" do
    params = {
      user: {
        nickname: @nickname,
        wx_openid: @openid,
        avatar_url: @avatar_url
      }
    }

    service = AuthenticationService.new(login_params: params, login_type: :mock)
    result = service.call

    assert result.success?
    assert_equal @nickname, result.result[:user]["nickname"]
  end

  test "should mock login with default values when params missing" do
    service = AuthenticationService.new(login_params: {}, login_type: :mock)
    result = service.call

    assert result.success?
    assert_equal "DHH", result.result[:user]["nickname"]
    assert_equal "test_dhh_001", result.result[:user]["wx_openid"]
  end

  test "should return existing user when openid already exists" do
    # 先创建用户
    existing_user = create_test_user(:user, wx_openid: @openid, nickname: "原有用户")

    params = {
      openid: @openid,
      nickname: "新昵称"  # 不应该更新昵称
    }

    service = AuthenticationService.new(login_params: params, login_type: :mock)
    result = service.call

    assert result.success?
    # 应该保持原有昵称
    assert_equal "原有用户", result.result[:user]["nickname"]
    assert_equal existing_user.id, result.result[:user]["id"]
  end

  test "should generate valid JWT token" do
    service = AuthenticationService.new(login_params: { openid: @openid }, login_type: :mock)
    result = service.call

    assert result.success?
    token = result.result[:token]

    # 验证token可以解码
    decoded = User.decode_jwt_token(token)
    assert_not_nil decoded
    assert_equal @openid, decoded[:wx_openid]
  end

  # 微信登录测试
  test "should fail wechat login when code is missing" do
    service = AuthenticationService.new(login_params: {}, login_type: :wechat)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "缺少 code 参数"
  end

  test "should fail wechat login when wechat API fails" do
    params = { code: "invalid_code" }

    service = AuthenticationService.new(login_params: params, login_type: :wechat)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "微信登录失败"
  end

  test "should handle unsupported login type" do
    service = AuthenticationService.new(login_params: {}, login_type: :unsupported)
    result = service.call

    assert result.failure?
    assert_includes result.error_messages, "不支持的登录类型: unsupported"
  end

  # 类方法测试
  test "should mock login using class method" do
    params = { openid: @openid, nickname: @nickname }

    result = AuthenticationService.mock_login!(params)

    assert result.success?
    assert_equal @nickname, result.result[:user]["nickname"]
    assert_equal @openid, result.result[:user]["wx_openid"]
  end

  test "should wechat login using class method" do
    result = AuthenticationService.wechat_login!({ code: "test_code" })

    assert result.failure?
    assert_includes result.error_messages, "微信登录失败"
  end

  # 参数处理测试
  test "should handle different openid param names" do
    params = {
      openid: "first_openid",
      user: { wx_openid: "second_openid" }
    }

    service = AuthenticationService.new(login_params: params, login_type: :mock)
    result = service.call

    assert result.success?
    # 应该优先使用顶级openid
    assert_equal "first_openid", result.result[:user]["wx_openid"]
  end

  test "should handle openid param in user object" do
    params = {
      user: {
        openid: "openid_in_user",
        nickname: @nickname
      }
    }

    service = AuthenticationService.new(login_params: params, login_type: :mock)
    result = service.call

    assert result.success?
    assert_equal "openid_in_user", result.result[:user]["wx_openid"]
  end

  # Token格式测试
  test "should include role in JWT token" do
    # 创建管理员用户测试
    admin_user = create_test_user(:admin, wx_openid: "admin_openid")

    service = AuthenticationService.new(login_params: { openid: "admin_openid" }, login_type: :mock)
    result = service.call

    assert result.success?
    token = result.result[:token]

    decoded = User.decode_jwt_token(token)
    assert_equal "admin", decoded[:role]
  end

  # 错误处理测试
  test "should handle user creation errors gracefully" do
    # 创建会导致验证冲突的参数
    existing_user = create_test_user(:user, wx_openid: @openid)

    # 再次尝试创建相同openid的用户
    params = { openid: @openid, nickname: "" }  # 空昵称应该验证失败

    service = AuthenticationService.new(login_params: params, login_type: :mock)
    result = service.call

    # 应该返回现有用户而不是错误（因为find_or_create_by）
    assert result.success?
    assert_equal existing_user.nickname, result.result[:user]["nickname"]
  end

  # 边界条件测试
  test "should handle very long nickname" do
    long_nickname = "a" * 100
    params = {
      openid: @openid,
      nickname: long_nickname
    }

    service = AuthenticationService.new(login_params: params, login_type: :mock)
    result = service.call

    assert result.success?
    assert_equal long_nickname, result.result[:user]["nickname"]
  end

  test "should handle very long openid" do
    long_openid = "a" * 100
    params = {
      openid: long_openid,
      nickname: @nickname
    }

    service = AuthenticationService.new(login_params: params, login_type: :mock)
    result = service.call

    assert result.success?
    assert_equal long_openid, result.result[:user]["wx_openid"]
  end

  test "should handle empty user data hash" do
    service = AuthenticationService.new(login_params: {}, login_type: :mock)
    result = service.call

    assert result.success?
    # 应该使用默认值
    assert_equal "DHH", result.result[:user]["nickname"]
    assert_equal "test_dhh_001", result.result[:user]["wx_openid"]
  end
end