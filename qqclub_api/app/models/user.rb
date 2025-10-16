class User < ApplicationRecord
  # 关联
  has_many :created_events, class_name: "ReadingEvent", foreign_key: "leader_id", dependent: :destroy
  has_many :enrollments, dependent: :destroy
  has_many :reading_events, through: :enrollments
  has_many :posts, dependent: :destroy

  # 验证
  validates :wx_openid, presence: true, uniqueness: true
  validates :wx_unionid, uniqueness: true, allow_nil: true
  validates :nickname, presence: true, length: { minimum: 1, maximum: 50 }, allow_blank: false

  # 枚举：用户角色（暂时注释掉以解决API问题）
  # enum role: %w[user admin root], default: 'user'

  # 生成 JWT token
  def generate_jwt_token
    payload = {
      user_id: id,
      wx_openid: wx_openid,
      role: role_as_string,  # 使用字符串角色名
      exp: 30.days.from_now.to_i,
      iat: Time.current.to_i,  # 签发时间
      type: 'access'  # token类型
    }
    JWT.encode(payload, Rails.application.credentials.jwt_secret_key || "dev_secret_key")
  end

  # 生成refresh token（长期有效）
  def generate_refresh_token
    payload = {
      user_id: id,
      wx_openid: wx_openid,
      type: 'refresh',
      exp: 90.days.from_now.to_i,  # 90天有效期
      iat: Time.current.to_i
    }
    JWT.encode(payload, Rails.application.credentials.jwt_secret_key || "dev_secret_key")
  end

  # 解析refresh token
  def self.decode_refresh_token(token)
    begin
      decoded = JWT.decode(token, Rails.application.credentials.jwt_secret_key || "dev_secret_key")[0]
      return nil unless decoded['type'] == 'refresh'
      HashWithIndifferentAccess.new(decoded)
    rescue JWT::DecodeError => e
      Rails.logger.warn "Refresh token解码失败: #{e.message}"
      nil
    end
  end

  # 使用refresh token生成新的access token
  def self.refresh_access_token(refresh_token)
    decoded = decode_refresh_token(refresh_token)
    return nil unless decoded

    user = User.find_by(id: decoded['user_id'])
    return nil unless user

    # 验证openid是否匹配
    return nil unless user.wx_openid == decoded['wx_openid']

    # 生成新的access token
    new_access_token = user.generate_jwt_token

    {
      access_token: new_access_token,
      refresh_token: refresh_token,  # refresh token可以继续使用
      user: user.as_json_for_api
    }
  end

  # 解析 JWT token
  def self.decode_jwt_token(token)
    begin
      decoded = JWT.decode(token, Rails.application.credentials.jwt_secret_key || "dev_secret_key")[0]
      HashWithIndifferentAccess.new(decoded)
    rescue JWT::DecodeError => e
      nil
    end
  end

  # 简化的角色权限检查方法
  def user?
    role.to_s == 'user' || role.to_s == '0'
  end

  def participant?
    role.to_s == 'user' || role.to_s == '0'  # 同义词，与user相同
  end

  def admin?
    role.to_s == 'admin' || role.to_s == '1'
  end

  def root?
    role.to_s == 'root' || role.to_s == '2'
  end

  def any_admin?
    admin? || root?
  end

  # 管理员权限检查
  def can_manage_users?
    root?
  end

  def can_approve_events?
    admin? || root?
  end

  def can_view_admin_panel?
    admin? || root?
  end

  def can_manage_system?
    root?
  end

  # 基础用户权限
  def can_create_posts?
    true  # 所有用户都可以发帖
  end

  def can_comment?
    true  # 所有用户都可以评论
  end

  def can_join_events?
    true  # 所有用户都可以报名活动
  end

  # 活动相关权限检查（基于 Enrollment，不是角色）
  def is_event_leader?(event)
    return false unless event
    event.leader_id == id
  end

  def is_daily_leader?(event, schedule)
    return false unless event && schedule
    return false unless schedule.reading_event_id == event.id
    schedule.daily_leader_id == id
  end

  # 角色提升方法
  def promote_to_admin!
    update!(role: 1) if user? || participant?  # 1 represents admin in integer form
  end

  def demote_to_user!
    update!(role: 0)  # 0 represents user in integer form
  end

  # 获取角色显示名称
  def role_display_name
    case role.to_s
    when 'user', '0'
      '用户'
    when 'admin', '1'
      '管理员'
    when 'root', '2'
      '超级管理员'
    else
      '未知角色'
    end
  end

  # 获取角色字符串名称（用于JWT token）
  def role_as_string
    case role.to_s
    when 'user', '0'
      'user'
    when 'admin', '1'
      'admin'
    when 'root', '2'
      'root'
    else
      'user'  # 默认为user
    end
  end

  # 检查用户是否有特定权限
  def has_permission?(permission)
    case permission
    when :approve_events
      can_approve_events?
    when :manage_users
      can_manage_users?
    when :view_admin_panel
      can_view_admin_panel?
    when :manage_system
      can_manage_system?
    when :create_posts
      can_create_posts?
    when :comment
      can_comment?
    when :join_events
      can_join_events?
    else
      false
    end
  end

  # 用于API响应的用户信息格式化
  def as_json_for_api
    {
      id: id,
      nickname: nickname,
      wx_openid: wx_openid,
      avatar_url: avatar_url,
      phone: phone,
      role: role_as_string
    }
  end
end
