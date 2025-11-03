# frozen_string_literal: true

module Api
  # 优化版本的PostsController - 解决N+1查询问题
  class OptimizedPostsController < Api::ApplicationController
    before_action :authenticate_user!
    include AdminAuthorizable

    # GET /api/posts
    def index
      # 基础查询，预加载所有必要的关联
      @posts = base_posts_query

      # 按分类筛选
      if params[:category].present?
        @posts = @posts.by_category(params[:category])
      end

      # 分页处理
      @posts = paginate_posts(@posts)

      # 批量预加载权限信息
      preload_permissions(@posts, current_user) if current_user

      # 批量预加载点赞状态
      preload_like_status(@posts, current_user) if current_user

      render json: optimized_posts_json(@posts)
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

      render json: optimized_post_json(@post)
    end

    private

    # 基础帖子查询
    def base_posts_query
      # 如果是管理员，可以看到所有帖子
      if current_user.any_admin?
        Post.includes(:user)
              .order(pinned: :desc, created_at: :desc)
      else
        Post.visible.includes(:user)
              .order(pinned: :desc, created_at: :desc)
      end
    end

    # 分页处理
    def paginate_posts(query)
      page = params[:page].to_i > 0 ? params[:page].to_i : 1
      per_page = params[:per_page].to_i > 0 ? [params[:per_page].to_i, 50].min : 20

      @total_count = query.count
      query.limit(per_page).offset((page - 1) * per_page)
    end

    # 批量预加载权限信息
    def preload_permissions(posts, user)
      post_ids = posts.map(&:id)

      # 批量获取权限信息
      permissions = PostPermissionService.batch_check_posts_permissions(
        post_ids,
        user.id,
        [:edit, :delete, :pin, :hide, :comment]
      )

      # 将权限信息附加到每个post对象
      posts.each do |post|
        post_id = post.id
        post.instance_variable_set(:@permissions, {
          can_edit: permissions.dig(:edit, post_id) || false,
          can_delete: permissions.dig(:delete, post_id) || false,
          can_pin: permissions.dig(:pin, post_id) || false,
          can_hide: permissions.dig(:hide, post_id) || false,
          can_comment: permissions.dig(:comment, post_id) || false
        })
      end
    end

    # 批量预加载点赞状态
    def preload_like_status(posts, user)
      post_ids = posts.map(&:id)

      # 一次性查询用户对所有帖子的点赞状态
      liked_post_ids = Like.where(
        user_id: user.id,
        target_type: 'Post',
        target_id: post_ids
      ).pluck(:target_id)

      # 将点赞状态附加到每个post对象
      posts.each do |post|
        post.instance_variable_set(:@current_user_liked, liked_post_ids.include?(post.id))
      end
    end

    # 优化的帖子JSON序列化
    def optimized_posts_json(posts)
      {
        posts: posts.map { |post| optimized_post_json(post, lite: true) },
        pagination: {
          current_page: params[:page].to_i > 0 ? params[:page].to_i : 1,
          per_page: params[:per_page].to_i > 0 ? [params[:per_page].to_i, 50].min : 20,
          total_count: @total_count,
          total_pages: (@total_count.to_f / [params[:per_page].to_i, 50].min).ceil,
          has_next: (params[:page].to_i > 0 ? params[:page].to_i : 1) * [params[:per_page].to_i, 50].min < @total_count,
          has_prev: (params[:page].to_i > 0 ? params[:page].to_i : 1) > 1
        }
      }
    end

    # 优化的单个帖子JSON序列化
    def optimized_post_json(post, lite: false)
      permissions = post.instance_variable_get(:@permissions) || {}
      liked_status = post.instance_variable_get(:@current_user_liked)

      result = {
        id: post.id,
        title: post.title,
        content: post.content,
        category: post.category,
        category_name: post.category_name,
        pinned: post.pinned,
        hidden: post.hidden,
        created_at: post.created_at,
        updated_at: post.updated_at,
        time_ago: post.time_ago_in_words(post.created_at),
        stats: {
          likes_count: post.likes_count,
          comments_count: post.comments_count
        },
        author: post.user.as_json_for_api
      }

      # 添加当前用户的交互状态（仅在需要时）
      if current_user && !lite
        result[:interactions] = {
          liked: liked_status || post.liked_by?(current_user),
          can_edit: permissions[:can_edit] || post.can_edit?(current_user),
          can_delete: permissions[:can_delete] || post.can_delete?(current_user),
          can_pin: permissions[:can_pin] || post.can_pin?(current_user),
          can_hide: permissions[:can_hide] || post.can_hide?(current_user),
          can_comment: permissions[:can_comment] || post.can_comment?(current_user)
        }
      end

      # 包含关联数据（仅在详情页面）
      if !lite && params[:include_comments] == 'true'
        result[:recent_comments] = post.comments.limit(5).includes(:user).map(&:as_json_for_api)
      end

      if !lite && params[:include_likes] == 'true'
        result[:recent_likes] = post.likes.limit(10).includes(:user).map do |like|
          {
            id: like.id,
            user: like.user.as_json_for_api,
            created_at: like.created_at
          }
        end
      end

      result
    end

    def post_params
      params.require(:post).permit(:title, :content, :category, :images, tags: [])
    end
  end
end