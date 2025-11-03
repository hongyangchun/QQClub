class Comment < ApplicationRecord
  belongs_to :post, optional: true
  belongs_to :user
  belongs_to :commentable, polymorphic: true

  # 验证
  validates :content, presence: true, length: { minimum: 2, maximum: 1000 }
  validates :commentable, presence: true, if: :should_validate_commentable?

  private

  def should_validate_commentable?
    commentable_type != 'CheckIn'
  end

  # 权限检查方法 - 改为公共方法
  def can_edit?(current_user)
    return false unless current_user
    return true if current_user.any_admin?  # 管理员可以编辑任何评论
    return true if user_id == current_user.id  # 作者可以编辑自己的评论
    false
  end

  # 时间格式化
  def time_ago
    seconds = Time.current - created_at
    minutes = seconds / 60
    hours = minutes / 60
    days = hours / 24

    if days >= 1
      "#{days.to_i}天前"
    elsif hours >= 1
      "#{hours.to_i}小时前"
    elsif minutes >= 1
      "#{minutes.to_i}分钟前"
    else
      "刚刚"
    end
  end

  # API序列化方法 - 标准化API响应格式
  def as_json_for_api(options = {})
    current_user = options[:current_user]

    result = {
      id: id,
      content: content,
      created_at: created_at,
      updated_at: updated_at,
      time_ago: time_ago,
      author: user.as_json_for_api
    }

    # 添加评论对象信息
    if commentable
      result[:commentable] = {
        type: commentable_type,
        id: commentable_id,
        title: commentable_title
      }
    end

    # 添加当前用户的权限信息
    if current_user
      result[:interactions] = {
        can_edit: can_edit?(current_user)
      }
    end

    # 包含回复评论
    if options[:include_replies]
      result[:replies] = replies.limit(5).map { |reply| reply.as_json_for_api(options) }
    end

    result
  end

  # JSON 序列化方法 - 保持向后兼容
  def as_json(options = {})
    json_hash = {
      id: id,
      content: content,
      created_at: created_at,
      updated_at: updated_at,
      author_info: author_info,
      time_ago: time_ago,
      can_edit_current_user: @can_edit_current_user || false
    }

    # 如果有关联的用户信息，包含用户数据
    if associated_user_loaded?
      json_hash[:user] = {
        id: user.id,
        nickname: user.nickname,
        avatar_url: user.avatar_url
      }
    end

    json_hash
  end

  # 设置当前用户是否可编辑的权限 - 改为公共方法
  def can_edit_current_user=(value)
    @can_edit_current_user = value
  end

  # 检查用户数据是否已预加载 - 改为公共方法
  def associated_user_loaded?
    loaded_associations = association(:user).loaded?
    loaded_associations
  rescue
    false
  end

  # 获取评论对象的标题
  def commentable_title
    return unless commentable

    case commentable_type
    when 'Post'
      commentable.title
    when 'CheckIn'
      "第#{commentable.day_number}天打卡"
    when 'ReadingEvent'
      commentable.title
    when 'Flower'
      "小红花 #{commentable.id}"
    else
      commentable_type
    end
  end

  # 获取回复评论
  def replies
    Comment.where(commentable_type: 'Comment', commentable_id: id)
  end

  private

  def author_info
    {
      id: user.id,
      nickname: user.nickname,
      avatar_url: user.avatar_url,
      role: user.role_display_name
    }
  end
end