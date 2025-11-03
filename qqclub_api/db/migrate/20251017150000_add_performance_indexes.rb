# frozen_string_literal: true

class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    # Posts表性能索引
    # 为分类筛选和复合状态查询添加索引
    add_index :posts, [:category, :created_at], name: 'index_posts_on_category_created'
    add_index :posts, [:hidden, :pinned, :created_at], name: 'index_posts_on_status_created'
    add_index :posts, [:user_id, :hidden, :created_at], name: 'index_posts_on_user_hidden_created'

    # Likes表性能索引
    # 为多态关联和点赞查询添加索引
    add_index :likes, [:target_type, :target_id, :user_id], name: 'index_likes_on_polymorphic_user'
    add_index :likes, [:target_type, :target_id, :created_at], name: 'index_likes_on_polymorphic_created'
    add_index :likes, [:target_type, :target_id], name: 'index_likes_on_polymorphic_target'

    # Comments表性能索引优化
    # 为帖子评论的复合查询添加索引
    add_index :comments, [:post_id, :created_at], name: 'index_comments_on_post_created_optimized'

    # 添加全文搜索索引（PostgreSQL特定）
    if connection.adapter_name.downcase.include?('postgresql')
      enable_extension :pg_trgm if extension_enabled?('pg_trgm').nil?
      enable_extension :btree_gin if extension_enabled?('btree_gin').nil?

      # 为帖子标题和内容添加全文搜索索引
      add_index :posts, :title, name: 'index_posts_on_title_trgm', using: :gin, opclass: :gin_trgm_ops
      add_index :posts, 'to_tsvector(\'simple\', title || \' \' || content)',
                name: 'index_posts_on_fulltext_search', using: :gin
    end

    # Flowers表性能索引优化
    # 为小红花的时间范围查询添加复合索引
    add_index :flowers, [:recipient_id, :created_at], name: 'index_flowers_recipient_created_optimized'
    add_index :flowers, [:giver_id, :created_at], name: 'index_flowers_giver_created_optimized'
    add_index :flowers, [:reading_schedule_id, :created_at], name: 'index_flowers_schedule_created'

    # Notifications表性能索引
    # 为通知查询添加复合索引
    add_index :notifications, [:recipient_id, :read, :created_at],
              name: 'index_notifications_unread_recent'
    add_index :notifications, [:notification_type, :created_at],
              name: 'index_notifications_type_created'

    # Users表性能索引
    # 为用户角色和时间相关查询添加索引
    add_index :users, [:role, :created_at], name: 'index_users_role_created'

    # ReadingEvents表性能索引
    # 为活动状态和审批状态添加索引
    add_index :reading_events, [:status, :start_date], name: 'index_events_status_start_date'
    add_index :reading_events, [:approval_status, :submitted_for_approval_at],
              name: 'index_events_approval_status_submitted'

    # CheckIns表性能索引
    # 为打卡查询添加复合索引
    add_index :check_ins, [:user_id, :reading_schedule_id, :created_at],
              name: 'index_checkins_user_schedule_created'
    add_index :check_ins, [:reading_schedule_id, :status, :created_at],
              name: 'index_checkins_schedule_status_created'

    # EventEnrollments表性能索引
    # 为活动报名查询添加索引
    add_index :event_enrollments, [:reading_event_id, :status, :enrollment_date],
              name: 'index_enrollments_event_status_date'
    add_index :event_enrollments, [:user_id, :status, :enrollment_date],
              name: 'index_enrollments_user_status_date'
  end

  private

  def extension_enabled?(name)
    result = execute("SELECT 1 FROM pg_extension WHERE extname = '#{name}'")
    result.count > 0
  rescue
    false
  end
end