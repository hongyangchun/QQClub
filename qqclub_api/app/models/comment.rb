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

  # JSON 序列化方法
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