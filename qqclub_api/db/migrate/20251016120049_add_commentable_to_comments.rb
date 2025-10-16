class AddCommentableToComments < ActiveRecord::Migration[8.0]
  def change
    # 添加多态关联字段，支持对打卡的评论
    add_reference :comments, :commentable, polymorphic: true, index: true

    # 为现有的帖子评论设置默认值
    Comment.where(commentable_type: nil).update_all(commentable_type: 'Post')
    Comment.where(commentable_id: nil).find_each do |comment|
      comment.update_column(:commentable_id, comment.post_id)
    end

    # 暂时保留post_id字段，后续可以删除
    # add_reference :comments, :post, null: false, foreign_key: true
  end
end
