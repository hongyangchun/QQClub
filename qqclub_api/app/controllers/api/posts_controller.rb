module Api
  class PostsController < Api::ApplicationController
    before_action :authenticate_user!
    include AdminAuthorizable

    # GET /api/posts
    def index
      @posts = Post.visible.includes(:user).pinned_first

      # 如果是管理员，可以看到所有帖子
      if current_user.any_admin?
        @posts = Post.includes(:user).pinned_first
      end

      # 按分类筛选
      if params[:category].present?
        @posts = @posts.by_category(params[:category])
      end

      render json: @posts.map { |post|
        post.instance_variable_set(:@can_edit_current_user, post.can_edit?(current_user))
        post.instance_variable_set(:@current_user, current_user)
        post.as_json
      }
    end

    # GET /api/posts/:id
    def show
      @post = Post.find(params[:id])

      # 检查权限：普通用户看不到隐藏帖子
      unless current_user.any_admin?
        if @post.hidden?
          return render json: { error: "帖子已被隐藏" }, status: :not_found
        end
      end

      @post.instance_variable_set(:@can_edit_current_user, @post.can_edit?(current_user))
      @post.instance_variable_set(:@current_user, current_user)
      render json: @post.as_json
    end

    # POST /api/posts
    def create
      # 使用PostManagementService处理帖子创建
      service_result = PostManagementService.create_post!(current_user, post_params)

      if service_result.success?
        render json: service_result.result, status: :created
      else
        render json: { errors: service_result.error_messages }, status: :unprocessable_entity
      end
    end

    # PUT /api/posts/:id
    def update
      @post = Post.find(params[:id])

      # 使用PostManagementService处理帖子更新
      service_result = PostManagementService.update_post!(@post, current_user, post_params)

      if service_result.success?
        render json: service_result.result
      else
        error_message = service_result.first_error
        status_code = error_message.include?("权限") ? :forbidden : :unprocessable_entity

        # 对于验证错误，使用errors格式；对于权限错误，使用error格式
        if service_result.error_messages.any? && service_result.error_messages.first.include?("can't be blank")
          render json: { errors: service_result.error_messages }, status: status_code
        else
          render json: { error: error_message }, status: status_code
        end
      end
    end

    # DELETE /api/posts/:id
    def destroy
      @post = Post.find(params[:id])

      # 使用PostManagementService处理帖子删除
      service_result = PostManagementService.delete_post!(@post, current_user)

      if service_result.success?
        head :no_content
      else
        error_message = service_result.first_error
        status_code = error_message.include?("权限") ? :forbidden : :unprocessable_entity
        render json: { error: error_message }, status: status_code
      end
    end

    # POST /api/posts/:id/pin  # 置顶帖子
    def pin
      authenticate_admin! and return

      @post = Post.find(params[:id])

      # 使用PostManagementService处理帖子置顶
      service_result = PostManagementService.pin_post!(@post, current_user)

      if service_result.success?
        render json: service_result.result
      else
        render json: { error: service_result.first_error }, status: :forbidden
      end
    end

    # POST /api/posts/:id/unpin  # 取消置顶
    def unpin
      authenticate_admin! and return

      @post = Post.find(params[:id])

      unless @post.can_pin?(current_user)
        render json: { error: "无权限取消置顶此帖子" }, status: :forbidden
        return
      end

      @post.unpin!
      render json: {
        message: "帖子已取消置顶",
        post: @post.as_json
      }
    end

    # POST /api/posts/:id/hide  # 隐藏帖子
    def hide
      authenticate_admin! and return

      @post = Post.find(params[:id])

      unless @post.can_hide?(current_user)
        render json: { error: "无权限隐藏此帖子" }, status: :forbidden
        return
      end

      @post.hide!
      render json: {
        message: "帖子已隐藏",
        post: @post.as_json
      }
    end

    # POST /api/posts/:id/unhide  # 显示帖子
    def unhide
      authenticate_admin! and return

      @post = Post.find(params[:id])

      unless @post.can_hide?(current_user)
        render json: { error: "无权限显示此帖子" }, status: :forbidden
        return
      end

      @post.unhide!
      render json: {
        message: "帖子已显示",
        post: @post.as_json
      }
    end

    # POST /api/posts/:id/like  # 点赞帖子
    def like
      @post = Post.find(params[:id])

      if Like.like!(current_user, @post)
        render json: {
          message: "点赞成功",
          liked: true,
          likes_count: @post.likes_count
        }
      else
        render json: { error: "已经点赞过了" }, status: :unprocessable_entity
      end
    end

    # DELETE /api/posts/:id/like  # 取消点赞
    def unlike
      @post = Post.find(params[:id])

      if Like.unlike!(current_user, @post)
        render json: {
          message: "取消点赞成功",
          liked: false,
          likes_count: @post.likes_count
        }
      else
        render json: { error: "还未点赞" }, status: :unprocessable_entity
      end
    end

    private

    def post_params
      params.require(:post).permit(:title, :content, :category, :images, tags: [])
    end
  end
end