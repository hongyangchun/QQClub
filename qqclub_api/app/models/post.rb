class Post < ApplicationRecord
  belongs_to :user, counter_cache: :posts_count
  has_many :comments, dependent: :destroy, counter_cache: true
  has_many :likes, as: :target, dependent: :destroy

  # 验证
  validates :title, presence: true, length: { maximum: 100 }
  validates :content, presence: true, length: { minimum: 10, maximum: 5000 }
  validates :category, inclusion: { in: %w[reading activity chat help], allow_blank: true }

  # 回调：手动维护多态关联的counter_cache
  after_create :initialize_counters

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

  # 统计点赞数 - 使用counter_cache
  # 注意：需要手动维护多态关联的counter_cache
  def likes_count
    self[:likes_count] || likes.count
  end

  # 统计评论数 - 使用counter_cache
  def comments_count
    self[:comments_count] || comments.count
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

  # API序列化方法 - 标准化API响应格式
  def as_json_for_api(options = {})
    current_user = options[:current_user]

    result = {
      id: id,
      title: title,
      content: content,
      category: category,
      category_name: category_name,
      pinned: pinned,
      hidden: hidden,
      created_at: created_at,
      updated_at: updated_at,
      time_ago: time_ago_in_words(created_at),
      stats: {
        likes_count: likes_count,
        comments_count: comments_count
      },
      author: user.as_json_for_api
    }

    # 添加标签信息
    if options[:include_tags] && respond_to?(:tags)
      result[:tags] = tags
    end

    # 添加当前用户的交互状态
    if current_user
      result[:interactions] = {
        liked: liked_by?(current_user),
        can_edit: can_edit?(current_user),
        can_hide: can_hide?(current_user),
        can_pin: can_pin?(current_user)
      }
    end

    # 包含关联数据
    if options[:include_comments]
      result[:recent_comments] = comments.limit(5).map(&:as_json_for_api)
    end

    if options[:include_likes]
      result[:recent_likes] = likes.limit(10).includes(:user).map do |like|
        {
          id: like.id,
          user: like.user.as_json_for_api,
          created_at: like.created_at
        }
      end
    end

    result
  end

  # JSON 序列化方法 - 保持向后兼容
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

  # 初始化计数器
  def initialize_counters
    # 新帖子初始化为0
    update_column(:likes_count, 0) if likes_count.nil?
    update_column(:comments_count, 0) if comments_count.nil?
  end

  # 手动更新点赞计数器
  def increment_likes_count
    increment!(:likes_count)
  end

  def decrement_likes_count
    decrement!(:likes_count)
  end
end
