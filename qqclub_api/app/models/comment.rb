class Comment < ApplicationRecord
  belongs_to :post
  belongs_to :user

  # 验证
  validates :content, presence: true, length: { minimum: 2, maximum: 1000 }

  # 权限检查方法
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
    super({
      methods: [:author_info, :time_ago, :can_edit_current_user],
      include: {
        user: {
          only: [:id, :nickname, :avatar_url]
        }
      }
    }.merge(options))
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

  def can_edit_current_user
    # 这个方法会在控制器中设置
    @can_edit_current_user || false
  end
end