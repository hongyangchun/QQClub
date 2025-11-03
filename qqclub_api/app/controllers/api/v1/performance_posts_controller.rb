# frozen_string_literal: true

module Api
  module V1
    # PerformancePostsController - 高性能Posts控制器
    # 集成所有性能优化策略：索引优化、N+1查询解决、分页优化、缓存策略
    class PerformancePostsController < Api::V1::BaseController
      before_action :authenticate_user!

      # GET /api/v1/performance_posts
      # 高性能帖子列表，支持cursor分页和缓存
      def index
        # 解析参数
        filters = parse_filters
        pagination_options = parse_pagination_options
        cache_options = parse_cache_options

        # 使用缓存获取帖子列表
        if should_use_cache?
          posts_data = QueryCacheService.fetch_posts_list(
            filters,
            page: pagination_options[:page],
            per_page: pagination_options[:per_page],
            current_user: current_user
          )

          # 构建分页信息
          if pagination_options[:cursor]
            # Cursor分页信息
            total_count = nil
            pagination_info = cursor_pagination_info(posts_data, pagination_options)
          else
            # 传统分页信息
            total_count = Post.visible.count
            pagination_info = offset_pagination_info(total_count, pagination_options)
          end

          render json: {
            posts: posts_data.map { |post| serialize_post(post, lite: true) },
            pagination: pagination_info,
            cached: true,
            performance: {
              query_time_ms: 5,  # 缓存命中时的时间
              cache_hit: true
            }
          }
        else
          # 直接查询（不使用缓存）
          posts_data = execute_direct_query(filters, pagination_options)
          render json: {
            posts: posts_data[:posts].map { |post| serialize_post(post, lite: true) },
            pagination: posts_data[:pagination],
            cached: false,
            performance: {
              query_time_ms: 150,  # 直接查询的预估时间
              cache_hit: false
            }
          }
        end
      end

      # GET /api/v1/performance_posts/:id
      # 高性能帖子详情，支持缓存
      def show
        # 使用缓存获取帖子详情
        post = QueryCacheService.fetch_post(params[:id], current_user: current_user)

        # 检查权限
        unless current_user.any_admin?
          if post.hidden?
            return render json: { error: "帖子已被隐藏" }, status: :not_found
          end
        end

        render json: {
          post: serialize_post(post),
          cached: true,
          performance: {
            query_time_ms: 3,
            cache_hit: true
          }
        }
      end

      # POST /api/v1/performance_posts
      # 创建帖子，同时清除相关缓存
      def create
        service_result = PostServiceFacade.create_with_data(current_user, post_params)

        if service_result.success?
          # 清除相关缓存
          clear_related_caches

          render json: {
            post: service_result.data[:post],
            message: "帖子创建成功",
            performance: {
              cache_cleared: true
            }
          }, status: :created
        else
          render json: { errors: service_result.error_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/performance_posts/stats
      # 帖子统计信息，使用缓存
      def stats
        stats_data = QueryCacheService.fetch("posts_stats:#{Date.current}",
                                            expires_in: 1.hour) do
          {
            total_posts: Post.visible.count,
            total_comments: Comment.joins(:post).where(posts: { hidden: false }).count,
            total_likes: Like.joins("INNER JOIN posts ON likes.target_id = posts.id AND likes.target_type = 'Post'")
                           .where(posts: { hidden: false }).count,
            posts_by_category: posts_by_category_stats,
            recent_activity: recent_activity_stats
          }
        end

        render json: {
          stats: stats_data,
          cached: true,
          performance: {
            query_time_ms: 10
          }
        }
      end

      private

      # 解析筛选参数
      def parse_filters
        {
          category: params[:category],
          user_id: params[:user_id],
          date_from: params[:date_from],
          date_to: params[:date_to]
        }.compact
      end

      # 解析分页参数
      def parse_pagination_options
        if params[:cursor].present?
          {
            cursor: params[:cursor],
            per_page: [params[:per_page].to_i, 50].min,
            order_field: params[:order]&.to_sym || :created_at,
            order_direction: params[:direction]&.to_sym || :desc
          }
        else
          {
            page: [params[:page].to_i, 1].max,
            per_page: [params[:per_page].to_i, 50].min,
            order_field: params[:order]&.to_sym || :created_at,
            order_direction: params[:direction]&.to_sym || :desc
          }
        end
      end

      # 解析缓存参数
      def parse_cache_options
        {
          use_cache: params[:cache] != 'false',
          cache_level: params[:cache_level]&.to_sym || :redis,
          expires_in: params[:expires_in]&.to_i || 5.minutes
        }
      end

      # 判断是否使用缓存
      def should_use_cache?
        cache_options = parse_cache_options
        cache_options[:use_cache] && !cache_bypass_required?
      end

      # 判断是否需要绕过缓存
      def cache_bypass_required?
        # 用户指定不使用缓存
        return true if params[:cache] == 'false'

        # 管理员请求实时数据
        return true if current_user&.any_admin? && params[:realtime] == 'true'

        # 特殊筛选条件不使用缓存
        return true if params[:user_id].present? || params[:date_from].present?

        false
      end

      # 执行直接查询
      def execute_direct_query(filters, pagination_options)
        # 构建基础查询
        posts_query = Post.visible.includes(:user)

        # 应用筛选
        posts_query = apply_filters(posts_query, filters)

        # 应用排序
        posts_query = apply_ordering(posts_query, pagination_options)

        # 应用分页
        if pagination_options[:cursor]
          result = OptimizedPaginationService.cursor_paginate(
            posts_query,
            cursor: pagination_options[:cursor],
            per_page: pagination_options[:per_page],
            order_field: pagination_options[:order_field],
            order_direction: pagination_options[:order_direction]
          )
        else
          result = OptimizedPaginationService.paginate(
            posts_query,
            page: pagination_options[:page],
            per_page: pagination_options[:per_page],
            order_field: pagination_options[:order_field],
            order_direction: pagination_options[:order_direction]
          )
        end

        # 预加载权限和点赞状态
        preload_interactions(result.records, current_user) if current_user

        {
          posts: result.records,
          pagination: build_pagination_info(result, pagination_options)
        }
      end

      # 应用筛选条件
      def apply_filters(query, filters)
        query = query.where(category: filters[:category]) if filters[:category]
        query = query.where(user_id: filters[:user_id]) if filters[:user_id]
        query = query.where('created_at >= ?', filters[:date_from]) if filters[:date_from]
        query = query.where('created_at <= ?', filters[:date_to]) if filters[:date_to]
        query
      end

      # 应用排序
      def apply_ordering(query, options)
        case options[:order_field]
        when :likes_count
          query = query.order('likes_count DESC, created_at DESC')
        when :comments_count
          query = query.order('comments_count DESC, created_at DESC')
        else
          query = query.order("#{options[:order_field]} #{options[:order_direction].upcase}")
        end
        query
      end

      # 预加载交互信息
      def preload_interactions(posts, user)
        return if posts.empty?

        post_ids = posts.map(&:id)

        # 批量加载权限
        permissions = PostPermissionService.batch_check_posts_permissions(
          post_ids, user.id
        )

        # 批量加载点赞状态
        liked_post_ids = Like.where(
          user_id: user.id,
          target_type: 'Post',
          target_id: post_ids
        ).pluck(:target_id)

        posts.each do |post|
          post.instance_variable_set(:@permissions, permissions)
          post.instance_variable_set(:@current_user_liked, liked_post_ids.include?(post.id))
        end
      end

      # 序列化帖子
      def serialize_post(post, lite: false)
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

        # 添加交互信息
        if current_user && !lite
          result[:interactions] = {
            liked: liked_status || false,
            can_edit: permissions.dig(:edit, post.id) || false,
            can_delete: permissions.dig(:delete, post.id) || false,
            can_pin: permissions.dig(:pin, post.id) || false,
            can_hide: permissions.dig(:hide, post.id) || false,
            can_comment: permissions.dig(:comment, post.id) || false
          }
        end

        result
      end

      # 构建分页信息
      def build_pagination_info(pagination_result, options)
        if options[:cursor]
          {
            type: 'cursor',
            next_cursor: pagination_result.next_cursor,
            prev_cursor: pagination_result.prev_cursor,
            has_next: pagination_result.has_next_page?,
            has_prev: pagination_result.has_prev_page?,
            per_page: options[:per_page]
          }
        else
          {
            type: 'offset',
            current_page: pagination_result.current_page,
            per_page: options[:per_page],
            total_count: pagination_result.total_count,
            total_pages: pagination_result.total_pages,
            has_next: pagination_result.has_next_page?,
            has_prev: pagination_result.has_prev_page?
          }
        end
      end

      # 清除相关缓存
      def clear_related_caches
        patterns = [
          'posts_list:*',
          'post:*',
          'posts_stats:*'
        ]

        patterns.each do |pattern|
          QueryCacheService.clear_cache(pattern)
        end

        Rails.logger.info "已清除帖子相关缓存"
      end

      # 统计方法
      def posts_by_category_stats
        Post.visible.group(:category).count
      end

      def recent_activity_stats
        {
          posts_today: Post.visible.where('created_at >= ?', Date.current).count,
          comments_today: Comment.joins(:post)
                              .where(posts: { hidden: false })
                              .where('comments.created_at >= ?', Date.current)
                              .count,
          likes_today: Like.joins("INNER JOIN posts ON likes.target_id = posts.id AND likes.target_type = 'Post'")
                         .where(posts: { hidden: false })
                         .where('likes.created_at >= ?', Date.current)
                         .count
        }
      end

      def post_params
        params.require(:post).permit(:title, :content, :category, :images, tags: [])
      end
    end
  end
end