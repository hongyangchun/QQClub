# frozen_string_literal: true

require "test_helper"

class LikeTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user(:user)
    @other_user = create_test_user(:user)
    @post = create_test_post(user: @user)
    @like = Like.new(
      user: @user,
      target: @post
    )
  end

  # Validations Tests
  test "should be valid with valid attributes" do
    assert @like.valid?
  end

  test "should require user" do
    @like.user = nil
    assert_not @like.valid?
    assert_includes @like.errors[:user], "must exist"
  end

  test "should require target" do
    @like.target = nil
    assert_not @like.valid?
  end

  test "should require target_type" do
    @like.target_type = nil
    assert_not @like.valid?
  end

  test "should require target_id" do
    @like.target_id = nil
    assert_not @like.valid?
  end

  test "should enforce uniqueness of user scoped to target" do
    @like.save!

    duplicate_like = Like.new(user: @user, target: @post)
    assert_not duplicate_like.valid?
    assert_includes duplicate_like.errors[:user_id], "has already been taken"
  end

  test "should allow different users to like same target" do
    @like.save!

    other_like = Like.new(user: @other_user, target: @post)
    assert other_like.valid?
    other_like.save!
    assert Like.exists?(user: @other_user, target: @post)
  end

  test "should allow same user to like different targets" do
    @like.save!

    other_post = create_test_post(user: @other_user)
    other_like = Like.new(user: @user, target: other_post)
    assert other_like.valid?
    other_like.save!
    assert Like.exists?(user: @user, target: other_post)
  end

  # Associations Tests
  test "should belong to user" do
    @like.save!
    assert_equal @user, @like.user
    assert_equal @user.id, @like.user_id
  end

  test "should belong to target with polymorphic association" do
    @like.save!
    assert_equal @post, @like.target
    assert_equal @post.class.name, @like.target_type
    assert_equal @post.id, @like.target_id
  end

  test "should work with post target" do
    @like.save!
    assert_equal @post, @like.target
    assert_equal 'Post', @like.target_type
  end

  test "should work with other target types" do
    # Test with Comment as target
    comment = create_test_comment(user: @user, post: @post)
    comment_like = Like.new(user: @other_user, target: comment)

    assert comment_like.valid?
    comment_like.save!
    assert_equal comment, comment_like.target
    assert_equal 'Comment', comment_like.target_type
  end

  test "should destroy like when user is destroyed" do
    @like.save!
    like_id = @like.id

    @user.destroy
    assert_not Like.exists?(like_id)
  end

  test "should destroy like when target is destroyed" do
    @like.save!
    like_id = @like.id

    @post.destroy
    assert_not Like.exists?(like_id)
  end

  # Class Methods Tests
  test "like! should create new like when not exists" do
    assert_not Like.exists?(user: @user, target: @post)

    result = Like.like!(@user, @post)

    assert result
    assert Like.exists?(user: @user, target: @post)
  end

  test "like! should return false when like already exists" do
    @like.save!

    result = Like.like!(@user, @post)

    assert_not result
    assert_equal 1, Like.where(user: @user, target: @post).count
  end

  test "like! should return false when user is nil" do
    result = Like.like!(nil, @post)
    assert_not result
  end

  test "like! should return false when target is nil" do
    result = Like.like!(@user, nil)
    assert_not result
  end

  test "unlike! should destroy existing like" do
    @like.save!
    assert Like.exists?(user: @user, target: @post)

    result = Like.unlike!(@user, @post)

    assert result
    assert_not Like.exists?(user: @user, target: @post)
  end

  test "unlike! should return false when like does not exist" do
    assert_not Like.exists?(user: @user, target: @post)

    result = Like.unlike!(@user, @post)

    assert_not result
  end

  test "unlike! should return false when user is nil" do
    result = Like.unlike!(nil, @post)
    assert_not result
  end

  test "unlike! should return false when target is nil" do
    result = Like.unlike!(@user, nil)
    assert_not result
  end

  test "liked? should return true when like exists" do
    @like.save!

    result = Like.liked?(@user, @post)

    assert result
  end

  test "liked? should return false when like does not exist" do
    result = Like.liked?(@user, @post)

    assert_not result
  end

  test "liked? should return false when user is nil" do
    result = Like.liked?(nil, @post)

    assert_not result
  end

  test "liked? should return false when target is nil" do
    result = Like.liked?(@user, nil)

    assert_not result
  end

  # Integration Tests
  test "should handle multiple users liking same target" do
    third_user = create_test_user(:user)

    Like.like!(@user, @post)
    Like.like!(@other_user, @post)
    Like.like!(third_user, @post)

    assert_equal 3, Like.where(target: @post).count
    assert Like.liked?(@user, @post)
    assert Like.liked?(@other_user, @post)
    assert Like.liked?(third_user, @post)
  end

  test "should handle user liking and unliking same target" do
    # Initial like
    assert Like.like!(@user, @post)
    assert Like.liked?(@user, @post)

    # Unlike
    assert Like.unlike!(@user, @post)
    assert_not Like.liked?(@user, @post)

    # Like again
    assert Like.like!(@user, @post)
    assert Like.liked?(@user, @post)
  end

  test "should handle likes on different target types" do
    comment = create_test_comment(user: @user, post: @post)

    # Like post
    Like.like!(@user, @post)

    # Like comment
    Like.like!(@other_user, comment)

    assert_equal 1, Like.where(target_type: 'Post', target: @post).count
    assert_equal 1, Like.where(target_type: 'Comment', target: comment).count
    assert Like.liked?(@user, @post)
    assert Like.liked?(@other_user, comment)
    assert_not Like.liked?(@user, comment)
    assert_not Like.liked?(@other_user, @post)
  end

  test "should maintain like counts correctly" do
    third_user = create_test_user(:user)

    initial_count = Like.where(target: @post).count

    Like.like!(@user, @post)
    assert_equal initial_count + 1, Like.where(target: @post).count

    Like.like!(@other_user, @post)
    assert_equal initial_count + 2, Like.where(target: @post).count

    Like.unlike!(@user, @post)
    assert_equal initial_count + 1, Like.where(target: @post).count

    Like.like!(third_user, @post)
    assert_equal initial_count + 2, Like.where(target: @post).count
  end

  # Edge Cases Tests
  test "should handle concurrent like attempts" do
    # Create separate users to avoid conflicts
    user1 = create_test_user(:user)
    user2 = create_test_user(:user)

    # Simulate concurrent like attempts
    results = []
    threads = []

    [user1, user2].each do |user|
      threads << Thread.new do
        results << Like.like!(user, @post)
      end
    end

    threads.each(&:join)

    # Both should succeed since they are different users
    assert_equal 2, results.count(true)
    assert_equal 0, results.count(false)
    assert_equal 2, Like.where(target: @post).count
  end

  test "should handle self-likes" do
    # User liking their own post should be allowed
    result = Like.like!(@user, @post)
    assert result
    assert Like.liked?(@user, @post)
  end

  # Performance Tests (basic)
  test "should handle large number of likes efficiently" do
    users = Array.new(10) { create_test_user(:user) }

    start_time = Time.current

    users.each do |user|
      Like.like!(user, @post)
    end

    end_time = Time.current

    # Should complete within reasonable time (adjust threshold as needed)
    assert (end_time - start_time) < 1.second
    assert_equal 10, Like.where(target: @post).count
  end

  private

  def create_test_comment(user:, post:, **attributes)
    default_attrs = {
      content: "Test comment",
      user: user,
      post: post
    }

    Comment.create!(default_attrs.merge(attributes))
  end
end