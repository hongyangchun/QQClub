# frozen_string_literal: true

require "test_helper"

class PostTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user(:user)
    @admin = create_test_user(:admin)
    @post = build(:post, user: @user)
  end

  # Validations Tests
  test "should be valid with valid attributes" do
    assert @post.valid?
  end

  test "should require title" do
    @post.title = nil
    assert_not @post.valid?
    assert_includes @post.errors[:title], "can't be blank"
  end

  test "should require title length maximum 100 characters" do
    @post.title = "a" * 101
    assert_not @post.valid?
    assert_includes @post.errors[:title], "is too long (maximum is 100 characters)"
  end

  test "should allow title within length limit" do
    @post.title = "a" * 100
    assert @post.valid?
  end

  test "should require content" do
    @post.content = nil
    assert_not @post.valid?
    assert_includes @post.errors[:content], "can't be blank"
  end

  test "should require content minimum 10 characters" do
    @post.content = "a" * 9
    assert_not @post.valid?
    assert_includes @post.errors[:content], "is too short (minimum is 10 characters)"
  end

  test "should allow content with minimum length" do
    @post.content = "a" * 10
    assert @post.valid?
  end

  test "should require content maximum 5000 characters" do
    @post.content = "a" * 5001
    assert_not @post.valid?
    assert_includes @post.errors[:content], "is too long (maximum is 5000 characters)"
  end

  test "should allow content within length limit" do
    @post.content = "a" * 5000
    assert @post.valid?
  end

  # Associations Tests
  test "should belong to user" do
    @post.save!
    assert_equal @user, @post.user
    assert_equal @user.id, @post.user_id
  end

  # Scopes Tests
  test "visible scope should return only non-hidden posts" do
    visible_post = create_test_post(user: @user, hidden: false)
    hidden_post = create_test_post(user: @user, hidden: true)

    visible_posts = Post.visible
    assert_includes visible_posts, visible_post
    assert_not_includes visible_posts, hidden_post
  end

  test "pinned_first scope should order posts by pinned status then created_at" do
    old_post = create_test_post(user: @user, created_at: 2.days.ago, pinned: false)
    new_post = create_test_post(user: @user, created_at: 1.day.ago, pinned: false)
    pinned_old_post = create_test_post(user: @user, created_at: 3.days.ago, pinned: true)
    pinned_new_post = create_test_post(user: @user, created_at: 1.day.ago, pinned: true)

    ordered_posts = Post.pinned_first

    # Pinned posts should come first, ordered by newest first
    assert_equal pinned_new_post, ordered_posts[0]
    assert_equal pinned_old_post, ordered_posts[1]

    # Non-pinned posts should come after, ordered by newest first
    assert_equal new_post, ordered_posts[2]
    assert_equal old_post, ordered_posts[3]
  end

  # Permission Methods Tests
  test "can_edit should return true for post author" do
    @post.save!
    assert @post.can_edit?(@user)
  end

  test "can_edit should return true for admin" do
    @post.save!
    assert @post.can_edit?(@admin)
  end

  test "can_edit should return false for other users" do
    @post.save!
    other_user = create_test_user(:user)
    assert_not @post.can_edit?(other_user)
  end

  test "can_edit should return false for nil user" do
    @post.save!
    assert_not @post.can_edit?(nil)
  end

  test "can_edit should return true for root user" do
    root_user = create_test_user(:root)
    @post.save!
    assert @post.can_edit?(root_user)
  end

  test "can_hide should return true for admin" do
    @post.save!
    assert @post.can_hide?(@admin)
  end

  test "can_hide should return true for root user" do
    root_user = create_test_user(:root)
    @post.save!
    assert @post.can_hide?(root_user)
  end

  test "can_hide should return false for regular user" do
    @post.save!
    assert_not @post.can_hide?(@user)
  end

  test "can_hide should return false for nil user" do
    @post.save!
    assert_not @post.can_hide?(nil)
  end

  test "can_pin should return true for admin" do
    @post.save!
    assert @post.can_pin?(@admin)
  end

  test "can_pin should return true for root user" do
    root_user = create_test_user(:root)
    @post.save!
    assert @post.can_pin?(root_user)
  end

  test "can_pin should return false for regular user" do
    @post.save!
    assert_not @post.can_pin?(@user)
  end

  test "can_pin should return false for nil user" do
    @post.save!
    assert_not @post.can_pin?(nil)
  end

  # Management Methods Tests
  test "hide should hide the post" do
    @post.save!
    assert_not @post.hidden?

    @post.hide!
    assert @post.hidden?
  end

  test "unhide should unhide the post" do
    @post.save!
    @post.update!(hidden: true)
    assert @post.hidden?

    @post.unhide!
    assert_not @post.hidden?
  end

  test "pin should pin the post" do
    @post.save!
    assert_not @post.pinned?

    @post.pin!
    assert @post.pinned?
  end

  test "unpin should unpin the post" do
    @post.save!
    @post.update!(pinned: true)
    assert @post.pinned?

    @post.unpin!
    assert_not @post.pinned?
  end

  # JSON Serialization Tests
  test "as_json should include author_info method" do
    @post.save!
    json = @post.as_json

    assert json["author_info"]
    assert_equal @user.id, json["author_info"]["id"]
    assert_equal @user.nickname, json["author_info"]["nickname"]
    assert_equal @user.avatar_url, json["author_info"]["avatar_url"]
    assert_equal @user.role_display_name, json["author_info"]["role"]
  end

  test "as_json should include can_edit_current_user method" do
    @post.save!
    @post.instance_variable_set(:@can_edit_current_user, true)
    json = @post.as_json

    assert_equal true, json["can_edit_current_user"]
  end

  test "as_json should include time_ago method" do
    @post.save!
    json = @post.as_json

    assert json["time_ago"]
    assert json["time_ago"].is_a?(String)
  end

  test "as_json should include user association" do
    @post.save!
    json = @post.as_json

    assert json["user"]
    assert_equal @user.id, json["user"]["id"]
    assert_equal @user.nickname, json["user"]["nickname"]
    assert_equal @user.avatar_url, json["user"]["avatar_url"]
  end

  # Time Ago Tests
  test "time_ago should return correct format for seconds" do
    @post.save!
    # Freeze time to ensure consistent test results
    travel_to Time.current do
      @post.update!(created_at: 30.seconds.ago)
      assert_equal "刚刚", @post.send(:time_ago)
    end
  end

  test "time_ago should return correct format for minutes" do
    @post.save!
    travel_to Time.current do
      @post.update!(created_at: 5.minutes.ago)
      assert_equal "5分钟前", @post.send(:time_ago)
    end
  end

  test "time_ago should return correct format for hours" do
    @post.save!
    travel_to Time.current do
      @post.update!(created_at: 3.hours.ago)
      assert_equal "3小时前", @post.send(:time_ago)
    end
  end

  test "time_ago should return correct format for days" do
    @post.save!
    travel_to Time.current do
      @post.update!(created_at: 2.days.ago)
      assert_equal "2天前", @post.send(:time_ago)
    end
  end

  # Edge Cases Tests
  test "should handle user role changes" do
    @post.save!
    regular_user = create_test_user(:user)

    # Regular user cannot edit
    assert_not @post.can_edit?(regular_user)

    # Promote to admin (use integer value as expected by database)
    regular_user.update!(role: 1)

    # Now can edit
    assert @post.can_edit?(regular_user)
  end

  test "should handle post with maximum title length" do
    @post.title = "a" * 100
    @post.content = "a" * 50
    assert @post.valid?
    @post.save!
    assert_equal 100, @post.title.length
  end

  test "should handle post with maximum content length" do
    @post.title = "Valid title"
    @post.content = "a" * 5000
    assert @post.valid?
    @post.save!
    assert_equal 5000, @post.content.length
  end

  test "should handle post with minimum content length" do
    @post.title = "Valid title"
    @post.content = "a" * 10
    assert @post.valid?
    @post.save!
    assert_equal 10, @post.content.length
  end
end