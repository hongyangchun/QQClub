class Like < ApplicationRecord
  belongs_to :user, counter_cache: :likes_given_count
  belongs_to :target, polymorphic: true

  # 验证
  validates :user_id, uniqueness: { scope: [:target_type, :target_id] }

  # 回调：维护目标对象的counter_cache
  after_create :increment_target_counter
  after_destroy :decrement_target_counter

  # 类方法：创建点赞
  def self.like!(user, target)
    return false unless user && target

    like = find_or_initialize_by(
      user: user,
      target: target
    )

    if like.new_record?
      like.save!
      true
    else
      false  # 已经点赞
    end
  end

  # 类方法：取消点赞
  def self.unlike!(user, target)
    return false unless user && target

    like = find_by(
      user: user,
      target: target
    )

    if like
      like.destroy!
      true
    else
      false  # 未点赞
    end
  end

  # 类方法：检查是否点赞
  def self.liked?(user, target)
    return false unless user && target
    exists?(user: user, target: target)
  end

  # API序列化方法 - 标准化API响应格式
  def as_json_for_api(options = {})
    result = {
      id: id,
      user: user.as_json_for_api,
      target_type: target_type,
      target_id: target_id,
      created_at: created_at
    }

    # 添加目标对象信息
    if options[:include_target] && target
      result[:target] = if target.respond_to?(:as_json_for_api)
                          target.as_json_for_api(options)
                        else
                          {
                            type: target_type,
                            id: target.id,
                            title: target_title
                          }
                        end
    end

    result
  end

  private

  # 获取目标对象的标题
  def target_title
    return unless target

    case target_type
    when 'Post'
      target.title
    when 'Comment'
      target.content.truncate(50)
    when 'CheckIn'
      "第#{target.day_number}天打卡"
    when 'ReadingEvent'
      target.title
    else
      target_type
    end
  end

  # 增加目标对象的计数器
  def increment_target_counter
    case target_type
    when 'Post'
      target.increment_likes_count if target.respond_to?(:increment_likes_count)
    end
  end

  # 减少目标对象的计数器
  def decrement_target_counter
    case target_type
    when 'Post'
      target.decrement_likes_count if target.respond_to?(:decrement_likes_count)
    end
  end
end