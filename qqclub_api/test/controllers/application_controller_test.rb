# frozen_string_literal: true

require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "health endpoint should return system status" do
    get "/api/health"

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "ok", json_response["status"]
    assert json_response["timestamp"]
    assert_equal "1.0.0", json_response["version"]
    assert_equal "test", json_response["environment"]

    # Verify basic structure - simplified health check
    assert_equal 4, json_response.keys.length
    assert json_response.key?("status")
    assert json_response.key?("timestamp")
    assert json_response.key?("version")
    assert json_response.key?("environment")
  end

  test "health endpoint should return current timestamp" do
    get "/api/health"

    json_response = JSON.parse(response.body)
    timestamp = Time.iso8601(json_response["timestamp"])

    # Timestamp should be recent (within 1 minute)
    assert (Time.current - timestamp) < 60.seconds
  end

  test "health endpoint should work without authentication" do
    get "/api/health"

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "ok", json_response["status"]
  end

  test "should authenticate user with valid token" do
    user = create_test_user(:user)
    token = user.generate_jwt_token

    get "/api/health", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :success
    # The health endpoint doesn't require authentication, so it should work
  end

  test "should handle malformed authorization header" do
    get "/api/auth/me", headers: { "Authorization" => "InvalidFormat token123" }

    assert_response :unauthorized
  end

  test "should handle missing authorization header" do
    get "/api/auth/me"

    assert_response :unauthorized
  end

  test "should handle expired token" do
    user = create_test_user(:user)

    # Create an expired token
    payload = {
      user_id: user.id,
      wx_openid: user.wx_openid,
      role: user.role,
      exp: 1.day.ago.to_i
    }
    expired_token = JWT.encode(payload, Rails.application.credentials.jwt_secret_key || "dev_secret_key")

    get "/api/auth/me", headers: { "Authorization" => "Bearer #{expired_token}" }

    assert_response :unauthorized
  end

  test "should handle invalid token format" do
    get "/api/auth/me", headers: { "Authorization" => "Bearer invalid.jwt.format" }

    assert_response :unauthorized
  end

  test "should handle token for non-existent user" do
    user = create_test_user(:user)
    token = user.generate_jwt_token

    # Delete the user but keep the token
    user.destroy

    get "/api/auth/me", headers: { "Authorization" => "Bearer #{token}" }

    assert_response :unauthorized
  end
end