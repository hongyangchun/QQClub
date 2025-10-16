# frozen_string_literal: true

class FixUserAvatars < ActiveRecord::Migration[7.0]
  def up
    # 修复所有使用默认头像或没有头像的用户
    User.where(avatar_url: [nil, '']).find_each do |user|
      user.update!(
        avatar_url: AvatarGeneratorService.generate_themed_avatar(
          nickname: user.nickname || "用户",
          user_id: user.id
        )
      )
    end

    # 修复使用example.com头像的用户
    User.where("avatar_url LIKE '%example.com/avatar%'").find_each do |user|
      user.update!(
        avatar_url: AvatarGeneratorService.generate_themed_avatar(
          nickname: user.nickname || "用户",
          user_id: user.id
        )
      )
    end
  end

  def down
    # 回滚操作：将所有随机生成的头像设置为默认值
    User.where.not(avatar_url: [nil, '']).find_each do |user|
      user.update!(avatar_url: "https://example.com/avatar.jpg")
    end
  end
end