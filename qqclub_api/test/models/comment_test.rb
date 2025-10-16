# frozen_string_literal: true

require "test_helper"

class CommentTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user(:user)
    @admin = create_test_user(:admin)
    @post = create_test_post(user: @user)
    @comment = Comment.new(
      content: "This is a test comment",
      user: @user,
      post: @post
    )
  end

  # Validations Tests
  test "should be valid with valid attributes" do
    assert @comment.valid?
  end

  test "should require content" do
    @comment.content = nil
    assert_not @comment.valid?
    assert_includes @comment.errors[:content], "can't be blank"
  end

  test "should require content minimum 2 characters" do
    @comment.content = "a"
    assert_not @comment.valid?
    assert_includes @comment.errors[:content], "is too short (minimum is 2 characters)"
  end

  test "should allow content with minimum length" do
    @comment.content = "aa"
    assert @comment.valid?
  end

  test "should require content maximum 1000 characters" do
    @comment.content = "a" * 1001
    assert_not @comment.valid?
    assert_includes @comment.errors[:content], "is too long (maximum is 1000 characters)"
  end

  test "should allow content within length limit" do
    @comment.content = "a" * 1000
    assert @comment.valid?
  end

  # Associations Tests
  test "should belong to post" do
    @comment.save!
    assert_equal @post, @comment.post
    assert_equal @post.id, @comment.post_id
  end

  test "should belong to user" do
    @comment.save!
    assert_equal @user, @comment.user
    assert_equal @user.id, @comment.user_id
  end

  test "should destroy comment when post is destroyed" do
    @comment.save!
    comment_id = @comment.id

    @post.destroy
    assert_not Comment.exists?(comment_id)
  end

  test "should destroy comment when user is destroyed" do
    @comment.save!
    comment_id = @comment.id

    @user.destroy
    assert_not Comment.exists?(comment_id)
  end

  # Permission Methods Tests
  test "can_edit should return true for comment author" do
    @comment.save!
    assert @comment.can_edit?(@user)
  end

  test "can_edit should return true for admin" do
    @comment.save!
    assert @comment.can_edit?(@admin)
  end

  test "can_edit should return false for other users" do
    @comment.save!
    other_user = create_test_user(:user)
    assert_not @comment.can_edit?(other_user)
  end

  test "can_edit should return false for nil user" do
    @comment.save!
    assert_not @comment.can_edit?(nil)
  end

  # Time Ago Tests
  test "time_ago should return correct format for seconds" do
    @comment.save!
    travel_to Time.current do
      @comment.update!(created_at: 30.seconds.ago)
      assert_equal "刚刚", @comment.time_ago
    end
  end

  test "time_ago should return correct format for minutes" do
    @comment.save!
    travel_to Time.current do
      @comment.update!(created_at: 5.minutes.ago)
      assert_equal "5分钟前", @comment.time_ago
    end
  end

  test "time_ago should return correct format for hours" do
    @comment.save!
    travel_to Time.current do
      @comment.update!(created_at: 3.hours.ago)
      assert_equal "3小时前", @comment.time_ago
    end
  end

  test "time_ago should return correct format for days" do
    @comment.save!
    travel_to Time.current do
      @comment.update!(created_at: 2.days.ago)
      assert_equal "2天前", @comment.time_ago
    end
  end

  # JSON Serialization Tests
  test "as_json should include author_info method" do
    @comment.save!
    json = @comment.as_json

    assert json["author_info"]
    assert_equal @user.id, json["author_info"]["id"]
    assert_equal @user.nickname, json["author_info"]["nickname"]
    assert_equal @user.avatar_url, json["author_info"]["avatar_url"]
    assert_equal @user.role_display_name, json["author_info"]["role"]
  end

  test "as_json should include time_ago method" do
    @comment.save!
    json = @comment.as_json

    assert json["time_ago"]
    assert json["time_ago"].is_a?(String)
  end

  test "as_json should include can_edit_current_user method" do
    @comment.save!
    @comment.instance_variable_set(:@can_edit_current_user, true)
    json = @comment.as_json

    assert_equal true, json["can_edit_current_user"]
  end

  test "as_json should include user association" do
    @comment.save!
    json = @comment.as_json

    assert json["user"]
    assert_equal @user.id, json["user"]["id"]
    assert_equal @user.nickname, json["user"]["nickname"]
    assert_equal @user.avatar_url, json["user"]["avatar_url"]
  end

  # Private Methods Tests
  test "author_info should return correct structure" do
    @comment.save!
    author_info = @comment.send(:author_info)

    assert_equal @user.id, author_info[:id]
    assert_equal @user.nickname, author_info[:nickname]
    assert_equal @user.avatar_url, author_info[:avatar_url]
    assert_equal @user.role_display_name, author_info[:role]
  end

  test "can_edit_current_user should return false by default" do
    @comment.save!
    can_edit = @comment.send(:can_edit_current_user)
    assert_equal false, can_edit
  end

  # Edge Cases Tests
  test "should handle comment with maximum content length" do
    @comment.content = "a" * 1000
    assert @comment.valid?
    @comment.save!
    assert_equal 1000, @comment.content.length
  end

  test "should handle comment with minimum content length" do
    @comment.content = "aa"
    assert @comment.valid?
    @comment.save!
    assert_equal 2, @comment.content.length
  end

  test "should handle unicode content" do
    @comment.content = "这是一个包含中文的评论内容 🎉"
    assert @comment.valid?
    @comment.save!
    assert_equal "这是一个包含中文的评论内容 🎉", @comment.content
  end

  test "should handle comments with different user roles" do
    @comment.save!

    # Regular user (author) can edit
    assert @comment.can_edit?(@user)

    # Admin can edit
    assert @comment.can_edit?(@admin)

    # Root user can edit
    root_user = create_test_user(:root)
    assert @comment.can_edit?(root_user)

    # Other regular user cannot edit
    other_user = create_test_user(:user)
    assert_not @comment.can_edit?(other_user)
  end

  test "should handle recently created comments" do
    @comment.save!

    travel_to Time.current do
      @comment.update!(created_at: 59.seconds.ago)
      assert_equal "刚刚", @comment.time_ago
    end
  end

  test "should handle old comments" do
    @comment.save!

    travel_to Time.current do
      @comment.update!(created_at: 10.days.ago)
      assert_equal "10天前", @comment.time_ago
    end
  end

  # Integration Tests
  test "should create comment through post association" do
    new_comment = @post.comments.create!(
      content: "Test comment through association",
      user: @user
    )

    assert_equal @post, new_comment.post
    assert_equal @user, new_comment.user
    assert_includes @post.comments, new_comment
  end

  test "should maintain comment count in post" do
    initial_count = @post.comments.count

    @comment.save!
    assert_equal initial_count + 1, @post.comments.count

    @comment.destroy
    assert_equal initial_count, @post.comments.count
  end
end