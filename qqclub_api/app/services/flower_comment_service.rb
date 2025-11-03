# 小红花评论服务
# 负责管理小红花的评论功能，包括创建、查询和权限管理
class FlowerCommentService
  class << self
    # 为小红花添加评论
    def add_comment_to_flower(flower, user, content)
      return { success: false, error: '小红花不存在' } unless flower
      return { success: false, error: '用户不存在' } unless user
      return { success: false, error: '评论内容不能为空' } if content.blank?

      # 验证评论权限
      unless can_comment_on_flower?(flower, user)
        return { success: false, error: '您没有权限评论此小红花' }
      end

      # 内容验证
      unless valid_comment_content?(content)
        return { success: false, error: '评论内容长度应在2-1000字符之间' }
      end

      # 创建评论
      comment = flower.add_comment(user, content)

      # 发布小红花评论事件，解耦通知服务
      DomainEventsService.publish('flower.comment_created', {
        flower: flower,
        commenter: user,
        comment: comment
      })

      {
        success: true,
        comment: comment.as_json_for_api,
        message: '评论添加成功'
      }
    rescue => e
      Rails.logger.error "小红花评论添加失败: #{e.message}"
      {
        success: false,
        error: '评论添加失败，请重试',
        details: e.message
      }
    end

    # 获取小红花的评论列表
    def get_flower_comments(flower, page = 1, limit = 10, current_user: nil)
      return { success: false, error: '小红花不存在' } unless flower

      # 分页查询评论
      comments = flower.comments
                     .includes(:user)
                     .order(created_at: :desc)
                     .offset((page - 1) * limit)
                     .limit(limit)

      # 检查用户权限
      can_comment = current_user ? can_comment_on_flower?(flower, current_user) : false

      {
        success: true,
        flower: {
          id: flower.id,
          giver_display_name: flower.giver_display_name,
          recipient_display_name: flower.recipient_display_name,
          flower_type: flower.flower_type,
          created_at: flower.created_at
        },
        comments: comments.map do |comment|
          comment_data = comment.as_json_for_api
          comment_data[:can_edit] = current_user ? comment.can_edit?(current_user) : false
          comment_data
        end,
        pagination: {
          current_page: page,
          total_count: flower.comments_count,
          total_pages: (flower.comments_count.to_f / limit).ceil,
          has_next: (page * limit) < flower.comments_count,
          has_prev: page > 1
        },
        permissions: {
          can_comment: can_comment,
          total_comments: flower.comments_count
        }
      }
    end

    # 获取小红花的评论统计
    def get_flower_comment_stats(flower)
      return { success: false, error: '小红花不存在' } unless flower

      comments = flower.comments.includes(:user)

      # 计算统计数据
      stats = {
        total_count: comments.count,
        today_count: comments.where(created_at: Date.current.all_day).count,
        this_week_count: comments.where(created_at: Date.current.beginning_of_week..Date.current.end_of_week).count,
        unique_users: comments.distinct.count(:user_id),
        avg_comment_length: comments.average("LENGTH(content)")&.round(2) || 0
      }

      # 最活跃的评论者
      active_commenters = comments.joins(:user)
                              .group('users.id', 'users.nickname')
                              .order('COUNT(*) DESC')
                              .limit(5)
                              .count

      {
        success: true,
        flower_id: flower.id,
        stats: stats,
        active_commenters: active_commenters.map { |user_id, nickname, count|
          {
            user_id: user_id,
            nickname: nickname,
            comment_count: count
          }
        },
        latest_comment: comments.order(created_at: :desc).first&.as_json_for_api
      }
    end

    # 删除小红花评论
    def delete_flower_comment(flower, comment, current_user)
      return { success: false, error: '评论不存在' } unless comment
      return { success: false, error: '小红花不存在' } unless flower
      return { success: false, error: '用户不存在' } unless current_user

      # 检查删除权限
      unless can_delete_comment?(comment, current_user)
        return { success: false, error: '您没有权限删除此评论' }
      end

      # 删除评论
      comment.destroy

      {
        success: true,
        message: '评论已删除',
        remaining_comments: flower.comments_count
      }
    rescue => e
      Rails.logger.error "小红花评论删除失败: #{e.message}"
      {
        success: false,
        error: '评论删除失败，请重试',
        details: e.message
      }
    end

    # 批量删除小红花评论（管理员功能）
    def batch_delete_flower_comments(flower, comment_ids, admin_user)
      return { success: false, error: '需要管理员权限' } unless admin_user&.any_admin?
      return { success: false, error: '小红花不存在' } unless flower

      # 查找要删除的评论
      comments = flower.comments.where(id: comment_ids)

      deleted_count = 0
      failed_comments = []

      comments.each do |comment|
        if comment.destroy
          deleted_count += 1
        else
          failed_comments << comment.id
        end
      end

      {
        success: failed_comments.empty?,
        deleted_count: deleted_count,
        failed_count: failed_comments.length,
        failed_comment_ids: failed_comments,
        remaining_comments: flower.comments_count,
        message: failed_comments.empty? ? "所有评论已删除" : "部分评论删除失败"
      }
    rescue => e
      Rails.logger.error "批量删除小红花评论失败: #{e.message}"
      {
        success: false,
        error: '批量删除失败，请重试',
        details: e.message
      }
    end

    # 搜索小红花评论
    def search_flower_comments(flower, keyword, page = 1, limit = 10, current_user: nil)
      return { success: false, error: '小红花不存在' } unless flower
      return { success: false, error: '搜索关键词不能为空' } if keyword.blank?

      # 搜索评论
      comments = flower.comments
                     .includes(:user)
                     .where('content ILIKE ?', "%#{keyword}%")
                     .order(created_at: :desc)
                     .offset((page - 1) * limit)
                     .limit(limit)

      {
        success: true,
        keyword: keyword,
        results: comments.map do |comment|
          comment_data = comment.as_json_for_api
          comment_data[:can_edit] = current_user ? comment.can_edit?(current_user) : false
          comment_data[:highlighted_content] = highlight_search_content(comment.content, keyword)
          comment_data
        end,
        pagination: {
          current_page: page,
          total_count: comments.count,
          total_pages: (comments.count.to_f / limit).ceil,
          has_next: (page * limit) < comments.count,
          has_prev: page > 1
        }
      }
    rescue => e
      Rails.logger.error "小红花评论搜索失败: #{e.message}"
      {
        success: false,
        error: '搜索失败，请重试',
        details: e.message
      }
    end

    private

    # 检查用户是否可以评论小红花
    def can_comment_on_flower?(flower, user)
      return false unless user && flower

      # 小红花接收者可以评论
      return true if flower.recipient_id == user.id

      # 小红花赠送者可以评论
      return true if flower.giver_id == user.id

      # 同一活动的参与者可以评论
      if flower.check_in && flower.check_in.reading_event
        event = flower.check_in.reading_event
        return true if event.participants.include?(user)
      end

      false
    end

    # 检查用户是否可以删除评论
    def can_delete_comment?(comment, user)
      return false unless user && comment

      # 评论作者可以删除自己的评论
      return true if comment.user_id == user.id

      # 管理员可以删除任何评论
      return true if user.any_admin?

      # 小红花接收者可以删除关于自己的小红花的评论
      if comment.commentable_type == 'Flower'
        flower = comment.commentable
        return true if flower.recipient_id == user.id
      end

      false
    end

    # 验证评论内容
    def valid_comment_content?(content)
      content_length = content.to_s.strip.length
      content_length >= 2 && content_length <= 1000
    end

    # 高亮搜索关键词
    def highlight_search_content(content, keyword)
      # 简单的关键词高亮实现
      content.gsub(/#{Regexp.escape(keyword)}/i, "**#{keyword}**")
    end

    # 发送小红花评论通知已移至事件订阅者中处理
    # 这样可以解耦FlowerCommentService和NotificationService的依赖关系
  end
end