class Post < ApplicationRecord
  belongs_to :user
  has_many :comments, dependent: :destroy
  has_many :likes, as: :target, dependent: :destroy

  # 验证
  validates :title, presence: true, length: { maximum: 100 }
  validates :content, presence: true, length: { minimum: 10, maximum: 5000 }
  validates :category, inclusion: { in: %w[reading activity chat help], allow_blank: true }

  # 作用域
  scope :visible, -> { where(hidden: false) }
  scope :pinned_first, -> { order(pinned: :desc, created_at: :desc) }
  scope :by_category, ->(category) { where(category: category) if category.present? }

  # 权限检查方法
  def can_edit?(current_user)
    return false unless current_user
    return true if current_user.any_admin?  # 管理员可以编辑任何帖子
    return true if user_id == current_user.id  # 作者可以编辑自己的帖子
    false
  end

  def can_hide?(current_user)
    current_user&.any_admin?
  end

  def can_pin?(current_user)
    current_user&.any_admin?
  end

  # 管理员操作方法
  def hide!
    update!(hidden: true)
  end

  def unhide!
    update!(hidden: false)
  end

  def pin!
    update!(pinned: true)
  end

  def unpin!
    update!(pinned: false)
  end

  # 公共辅助方法
  def can_edit_current_user
    # 这个方法会在控制器中设置
    @can_edit_current_user || false
  end

  def time_ago
    time_ago_in_words(created_at)
  end

  def time_ago_in_words(time)
    seconds = Time.current - time
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

  # 获取分类名称
  def category_name
    category_map = {
      'reading' => '读书心得',
      'activity' => '活动讨论',
      'chat' => '闲聊区',
      'help' => '求助问答'
    }
    category_map[category] || '全部'
  end

  # 统计点赞数
  def likes_count
    likes.count
  end

  # 统计评论数
  def comments_count
    comments.count
  end

  # 检查当前用户是否点赞
  def liked_by?(current_user)
    return false unless current_user
    likes.exists?(user_id: current_user.id)
  end

  # 检查当前用户是否点赞（用于JSON序列化）
  def liked_by_current_user
    current_user = @current_user
    return false unless current_user
    liked_by?(current_user)
  end

  # JSON 序列化方法
  def as_json(options = {})
    super({
      methods: [:author_info, :can_edit_current_user, :time_ago, :category_name, :likes_count, :comments_count, :tags, :liked_by_current_user],
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
end
