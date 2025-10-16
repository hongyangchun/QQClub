module Api
  class CommentsController < Api::ApplicationController
    include Commentable

    before_action :set_post, only: [:index, :create]

    private

    def fetch_comments
      @post.comments
    end

    def build_comment(params)
      comment = @post.comments.new(params)
      # 设置 commentable 关联
      comment.commentable = @post
      comment
    end

    def set_post
      @post = Post.find(params[:post_id])
    rescue ActiveRecord::RecordNotFound
      render_not_found('帖子不存在')
    end
  end
end