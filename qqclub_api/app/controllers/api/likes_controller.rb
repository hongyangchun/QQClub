module Api
  class LikesController < Api::ApplicationController
    before_action :authenticate_user!

    # POST /api/posts/:post_id/like
    def create
      target = find_target

      if target.nil?
        return render json: { error: '目标不存在' }, status: :not_found
      end

      if Like.like!(current_user, target)
        render json: {
          message: '点赞成功',
          liked: true,
          likes_count: target.likes_count
        }
      else
        render json: { error: '已经点赞过了' }, status: :unprocessable_entity
      end
    end

    # DELETE /api/posts/:post_id/like
    def destroy
      target = find_target

      if target.nil?
        return render json: { error: '目标不存在' }, status: :not_found
      end

      if Like.unlike!(current_user, target)
        render json: {
          message: '取消点赞成功',
          liked: false,
          likes_count: target.likes_count
        }
      else
        render json: { error: '还未点赞' }, status: :unprocessable_entity
      end
    end

    private

    def find_target
      case params[:post_id]
      when nil
        nil
      else
        Post.find(params[:post_id])
      end
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end
end