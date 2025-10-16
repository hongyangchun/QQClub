class OptimizeCommentsIndexes < ActiveRecord::Migration[8.0]
  def change
    # 添加复合索引以优化帖子评论查询和排序
    # 这个索引将优化: Comment.includes(:user).where(post_id: X).order(created_at: :asc)
    add_index :comments, [:post_id, :created_at], name: 'index_comments_on_post_id_and_created_at'

    # 为评论权限检查优化用户查询
    # user_id 索引已存在，但为了完整性我们确认一下它存在
    unless index_exists?(:comments, :user_id)
      add_index :comments, :user_id
    end

    # 确保多态关联索引存在（通常已存在）
    unless index_exists?(:comments, [:commentable_type, :commentable_id])
      add_index :comments, [:commentable_type, :commentable_id], name: 'index_comments_on_commentable'
    end

    # 为评论创建时间添加索引（用于时间范围查询）
    add_index :comments, :created_at, name: 'index_comments_on_created_at'
  end
end
