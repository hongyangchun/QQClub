# frozen_string_literal: true

# AvatarGeneratorService - 生成随机头像服务
# 使用 Picsum Photos API 生成随机头像
class AvatarGeneratorService < ApplicationService
  # 可用的头像主题和参数
  AVATAR_THEMES = %w[
    abstract animals architecture business cats city fashion
    food nature nightlife people sport technology transport
  ].freeze

  # 头像尺寸
  AVATAR_SIZES = [100, 200, 300, 400, 500].freeze

  # 生成用户头像URL
  def self.generate_user_avatar(user_id: nil, size: 200)
    # 基于用户ID生成一致的随机头像
    seed = user_id ? "user_#{user_id}" : "user_#{Time.current.to_i}_#{rand(1000)}"
    theme = AVATAR_THEMES.sample
    width = height = size

    # 使用 Picsum Photos API 生成随机头像
    "https://picsum.photos/seed/#{seed}/#{width}/#{height}.jpg"
  end

  # 生成动物头像（适合可爱风格）
  def self.generate_cute_avatar(user_id: nil)
    seed = user_id ? "cute_#{user_id}" : "cute_#{Time.current.to_i}_#{rand(1000)}"
    "https://picsum.photos/seed/#{seed}/200/200.jpg"
  end

  # 生成风景头像（适合通用风格）
  def self.generate_nature_avatar(user_id: nil)
    seed = user_id ? "nature_#{user_id}" : "nature_#{Time.current.to_i}_#{rand(1000)}"
    "https://picsum.photos/seed/#{seed}/200/200.jpg"
  end

  # 生成几何头像（适合现代风格）
  def self.generate_geometric_avatar(user_id: nil)
    seed = user_id ? "geo_#{user_id}" : "geo_#{Time.current.to_i}_#{rand(1000)}"
    "https://picsum.photos/seed/#{seed}/200/200.jpg"
  end

  # 根据用户昵称生成主题相关的头像
  def self.generate_themed_avatar(nickname: nil, user_id: nil)
    return generate_user_avatar(user_id: user_id) unless nickname

    # 根据昵称关键词选择主题
    theme_keywords = {
      '猫' => 'cats',
      '狗' => 'animals',
      '花' => 'nature',
      '树' => 'nature',
      '山' => 'nature',
      '海' => 'nature',
      '书' => 'business',
      '美食' => 'food',
      '运动' => 'sport',
      '音乐' => 'abstract',
      '科技' => 'technology',
      '城市' => 'city',
      '时尚' => 'fashion'
    }

    selected_theme = 'nature' # 默认主题
    theme_keywords.each do |keyword, theme|
      if nickname.include?(keyword)
        selected_theme = theme
        break
      end
    end

    seed = user_id ? "user_#{user_id}" : "user_#{Time.current.to_i}_#{rand(1000)}"
    "https://picsum.photos/seed/#{seed}_#{selected_theme}/200/200.jpg"
  end

  # 获取默认头像列表（用于测试）
  def self.default_avatars
    [
      'https://picsum.photos/seed/avatar1/200/200.jpg',
      'https://picsum.photos/seed/avatar2/200/200.jpg',
      'https://picsum.photos/seed/avatar3/200/200.jpg',
      'https://picsum.photos/seed/avatar4/200/200.jpg',
      'https://picsum.photos/seed/avatar5/200/200.jpg'
    ]
  end
end