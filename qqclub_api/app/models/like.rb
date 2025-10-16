class Like < ApplicationRecord
  belongs_to :user
  belongs_to :target, polymorphic: true

  # 验证
  validates :user_id, uniqueness: { scope: [:target_type, :target_id] }

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
end