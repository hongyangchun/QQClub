# frozen_string_literal: true

class AddCounterCaches < ActiveRecord::Migration[8.0]
  def change
    # 为Posts表添加counter_cache字段
    add_column :posts, :comments_count, :integer, default: 0, null: false
    add_column :posts, :likes_count, :integer, default: 0, null: false

    # 为CheckIns表添加counter_cache字段
    add_column :check_ins, :flowers_count, :integer, default: 0, null: false
    add_column :check_ins, :comments_count, :integer, default: 0, null: false

    # 为Users表添加counter_cache字段
    add_column :users, :posts_count, :integer, default: 0, null: false
    add_column :users, :comments_count, :integer, default: 0, null: false
    add_column :users, :likes_given_count, :integer, default: 0, null: false
    add_column :users, :flowers_given_count, :integer, default: 0, null: false
    add_column :users, :flowers_received_count, :integer, default: 0, null: false

    # 为ReadingEvents表添加counter_cache字段
    add_column :reading_events, :enrollments_count, :integer, default: 0, null: false
    add_column :reading_events, :check_ins_count, :integer, default: 0, null: false
    add_column :reading_events, :flowers_count, :integer, default: 0, null: false

    # 初始化counter_cache数据
    initialize_posts_counters
    initialize_check_ins_counters
    initialize_users_counters
    initialize_reading_events_counters

    # 为counter_cache字段添加索引
    add_index :posts, [:comments_count, :created_at], name: 'index_posts_comments_count_created'
    add_index :posts, [:likes_count, :created_at], name: 'index_posts_likes_count_created'
    add_index :users, :posts_count, name: 'index_users_posts_count'
    add_index :users, :flowers_received_count, name: 'index_users_flowers_received'
  end

  private

  def initialize_posts_counters
    # 初始化帖子的评论数和点赞数
    execute <<-SQL
      UPDATE posts SET
        comments_count = (
          SELECT COUNT(*)
          FROM comments
          WHERE comments.post_id = posts.id
        ),
        likes_count = (
          SELECT COUNT(*)
          FROM likes
          WHERE likes.target_type = 'Post' AND likes.target_id = posts.id
        )
    SQL
  end

  def initialize_check_ins_counters
    # 初始化打卡的小红花数和评论数
    execute <<-SQL
      UPDATE check_ins SET
        flowers_count = (
          SELECT COUNT(*)
          FROM flowers
          WHERE flowers.check_in_id = check_ins.id
        ),
        comments_count = (
          SELECT COUNT(*)
          FROM comments
          WHERE comments.commentable_type = 'CheckIn'
            AND comments.commentable_id = check_ins.id
        )
    SQL
  end

  def initialize_users_counters
    # 初始化用户的统计计数
    execute <<-SQL
      UPDATE users SET
        posts_count = (
          SELECT COUNT(*)
          FROM posts
          WHERE posts.user_id = users.id
        ),
        comments_count = (
          SELECT COUNT(*)
          FROM comments
          WHERE comments.user_id = users.id
        ),
        likes_given_count = (
          SELECT COUNT(*)
          FROM likes
          WHERE likes.user_id = users.id
        ),
        flowers_given_count = (
          SELECT COUNT(*)
          FROM flowers
          WHERE flowers.giver_id = users.id
        ),
        flowers_received_count = (
          SELECT COUNT(*)
          FROM flowers
          WHERE flowers.recipient_id = users.id
        )
    SQL
  end

  def initialize_reading_events_counters
    # 初始化活动的统计计数
    execute <<-SQL
      UPDATE reading_events SET
        enrollments_count = (
          SELECT COUNT(*)
          FROM event_enrollments
          WHERE event_enrollments.reading_event_id = reading_events.id
        ),
        check_ins_count = (
          SELECT COUNT(*)
          FROM check_ins
          INNER JOIN reading_schedules ON check_ins.reading_schedule_id = reading_schedules.id
          WHERE reading_schedules.reading_event_id = reading_events.id
        ),
        flowers_count = (
          SELECT COUNT(*)
          FROM flowers
          INNER JOIN check_ins ON flowers.check_in_id = check_ins.id
          INNER JOIN reading_schedules ON check_ins.reading_schedule_id = reading_schedules.id
          WHERE reading_schedules.reading_event_id = reading_events.id
        )
    SQL
  end
end