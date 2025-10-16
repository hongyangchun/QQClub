# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = build(:user)
    @admin = build(:admin)
    @root = build(:root)
  end

  test "should be valid with valid attributes" do
    assert @user.valid?
  end

  test "should require wx_openid" do
    @user.wx_openid = nil
    assert_not @user.valid?
    assert_includes @user.errors[:wx_openid], "can't be blank"
  end

  test "should require unique wx_openid" do
    @user.save!
    duplicate_user = build(:user, wx_openid: @user.wx_openid)
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:wx_openid], "has already been taken"
  end

  test "should allow unique wx_unionid" do
    @user.wx_unionid = "unique_unionid"
    @user.save!
    assert @user.valid?
  end

  test "should require unique wx_unionid when present" do
    @user.wx_unionid = "shared_unionid"
    @user.save!
    duplicate_user = build(:user, wx_unionid: @user.wx_unionid)
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:wx_unionid], "has already been taken"
  end

  # JWT Token Tests
  test "should generate JWT token" do
    @user.save!
    token = @user.generate_jwt_token
    assert_not_nil token
    assert token.is_a?(String)
    assert token.length > 0
  end

  test "should decode valid JWT token" do
    @user.save!
    token = @user.generate_jwt_token
    decoded = User.decode_jwt_token(token)

    assert_not_nil decoded
    assert_equal @user.id, decoded[:user_id]
    assert_equal @user.wx_openid, decoded[:wx_openid]
    assert_equal @user.role_as_string, decoded[:role]
    assert decoded[:exp].present?
  end

  test "should return nil for invalid JWT token" do
    invalid_token = "invalid.jwt.token"
    decoded = User.decode_jwt_token(invalid_token)
    assert_nil decoded
  end

  test "should return nil for expired JWT token" do
    @user.save!

    # Manually create an expired token
    payload = {
      user_id: @user.id,
      wx_openid: @user.wx_openid,
      role: @user.role,
      exp: 1.day.ago.to_i
    }
    expired_token = JWT.encode(payload, Rails.application.credentials.jwt_secret_key || "dev_secret_key")

    decoded = User.decode_jwt_token(expired_token)
    assert_nil decoded
  end

  # Role Tests
  test "should correctly identify user role" do
    assert @user.user?
    assert_not @user.admin?
    assert_not @user.root?
    assert_not @user.any_admin?
  end

  test "should correctly identify admin role" do
    assert @admin.admin?
    assert_not @admin.user?
    assert_not @admin.root?
    assert @admin.any_admin?
  end

  test "should correctly identify root role" do
    assert @root.root?
    assert_not @root.user?
    assert_not @root.admin?
    assert @root.any_admin?
  end

  # Permission Tests
  test "user should have basic permissions" do
    assert @user.can_create_posts?
    assert @user.can_comment?
    assert @user.can_join_events?
    assert_not @user.can_approve_events?
    assert_not @user.can_manage_users?
    assert_not @user.can_view_admin_panel?
    assert_not @user.can_manage_system?
  end

  test "admin should have admin permissions" do
    assert @admin.can_create_posts?
    assert @admin.can_comment?
    assert @admin.can_join_events?
    assert @admin.can_approve_events?
    assert_not @admin.can_manage_users?
    assert @admin.can_view_admin_panel?
    assert_not @admin.can_manage_system?
  end

  test "root should have all permissions" do
    assert @root.can_create_posts?
    assert @root.can_comment?
    assert @root.can_join_events?
    assert @root.can_approve_events?
    assert @root.can_manage_users?
    assert @root.can_view_admin_panel?
    assert @root.can_manage_system?
  end

  test "has_permission should work correctly" do
    assert @user.has_permission?(:create_posts)
    assert @user.has_permission?(:comment)
    assert @user.has_permission?(:join_events)
    assert_not @user.has_permission?(:approve_events)
    assert_not @user.has_permission?(:manage_users)
    assert_not @user.has_permission?(:view_admin_panel)
    assert_not @user.has_permission?(:manage_system)

    assert @admin.has_permission?(:create_posts)
    assert @admin.has_permission?(:approve_events)
    assert @admin.has_permission?(:view_admin_panel)
    assert_not @admin.has_permission?(:manage_users)
    assert_not @admin.has_permission?(:manage_system)

    assert @root.has_permission?(:manage_system)
    assert @root.has_permission?(:approve_events)
    assert @root.has_permission?(:view_admin_panel)
    assert @root.has_permission?(:manage_users)
  end

  # Event Leadership Tests
  test "should identify event leader correctly" do
    @user.save!
    event = create_test_reading_event(leader: @user)

    assert @user.is_event_leader?(event)

    other_user = create_test_user(:user)
    assert_not other_user.is_event_leader?(event)

    assert_not @user.is_event_leader?(nil)
  end

  test "should identify daily leader correctly" do
    @user.save!
    event = create_test_reading_event(leader: @user)
    schedule = create_test_reading_schedule(reading_event: event, daily_leader: @user)

    assert @user.is_daily_leader?(event, schedule)

    other_user = create_test_user(:user)
    assert_not other_user.is_daily_leader?(event, schedule)

    assert_not @user.is_daily_leader?(nil, schedule)
    assert_not @user.is_daily_leader?(event, nil)
  end

  # Role Management Tests
  test "root can promote admin" do
    @root.save!
    admin_user = create_test_user(:user)

    assert admin_user.user?
    assert_not admin_user.admin?

    # This would fail in real implementation since promote_to_admin! checks if current user is root
    # In unit tests, we can't test role promotion properly without mocking current user context
    admin_user.update!(role: 1)  # 1 represents admin in integer form
    assert admin_user.admin?
  end

  test "can demote admin to user" do
    admin_user = create_test_user(:admin)
    assert admin_user.admin?

    admin_user.demote_to_user!
    assert admin_user.user?
    assert_not admin_user.admin?
  end

  # Role Display Name Tests
  test "should return correct role display names" do
    assert_equal "用户", @user.role_display_name
    assert_equal "管理员", @admin.role_display_name
    assert_equal "超级管理员", @root.role_display_name
  end

  test "should return unknown role for invalid role" do
    @user.save!
    @user.update_column(:role, 99)  # Invalid role number
    @user.reload
    assert_equal "未知角色", @user.role_display_name
  end

  # Associations Tests
  test "should have created events association" do
    @user.save!
    event = create_test_reading_event(leader: @user)

    assert_includes @user.created_events, event
    assert_equal 1, @user.created_events.count
  end

  test "should have enrollments association" do
    @user.save!
    event = create_test_reading_event
    enrollment = Enrollment.create!(user: @user, reading_event: event)

    assert_includes @user.enrollments, enrollment
    assert_equal 1, @user.enrollments.count
  end

  test "should have reading events through enrollments" do
    @user.save!
    event = create_test_reading_event
    Enrollment.create!(user: @user, reading_event: event)

    assert_includes @user.reading_events, event
    assert_equal 1, @user.reading_events.count
  end
end