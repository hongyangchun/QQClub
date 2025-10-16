module Api
  class CommentsController < Api::ApplicationController
    before_action :authenticate_user!
    before_action :set_post
    before_action :set_comment, only: [:update, :destroy]

    # GET /api/posts/:post_id/comments
    def index
      @comments = @post.comments.includes(:user).order(created_at: :asc)

      render json: @comments.map { |comment|
        comment.instance_variable_set(:@can_edit_current_user, comment.can_edit?(current_user))
        comment.as_json
      }
    end

    # POST /api/posts/:post_id/comments
    def create
      @comment = @post.comments.new(comment_params)
      @comment.user = current_user

      if @comment.save
        @comment.instance_variable_set(:@can_edit_current_user, true)
        render json: {
          message: '评论发布成功',
          comment: @comment.as_json
        }, status: :created
      else
        render json: { errors: @comment.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PUT /api/comments/:id
    def update
      unless @comment.can_edit?(current_user)
        return render json: { error: '无权限编辑此评论' }, status: :forbidden
      end

      if @comment.update(comment_params)
        @comment.instance_variable_set(:@can_edit_current_user, true)
        render json: {
          message: '评论更新成功',
          comment: @comment.as_json
        }
      else
        render json: { errors: @comment.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/comments/:id
    def destroy
      unless @comment.can_edit?(current_user)
        return render json: { error: '无权限删除此评论' }, status: :forbidden
      end

      @comment.destroy
      head :no_content
    end

    private

    def set_post
      @post = Post.find(params[:post_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: '帖子不存在' }, status: :not_found
    end

    def set_comment
      @comment = Comment.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: '评论不存在' }, status: :not_found
    end

    def comment_params
      params.require(:comment).permit(:content)
    end
  end
end