# frozen_string_literal: true

# AuthenticationService - 用户认证逻辑服务
# 负责微信登录、模拟登录、用户创建/查找等业务逻辑
class AuthenticationService < ApplicationService
  attr_reader :login_params, :user, :login_type

  def initialize(login_params: {}, login_type: :mock)
    super()
    @login_params = login_params
    @login_type = login_type
    @user = nil
  end

  # 主要调用方法
  def call
    handle_errors do
      case login_type
      when :mock
        mock_login
      when :wechat
        wechat_login
      else
        failure!("不支持的登录类型: #{login_type}")
      end
    end
    self  # 返回service实例
  end

  # 类方法：模拟登录
  def self.mock_login!(params = {})
    new(login_params: params, login_type: :mock).call
  end

  # 类方法：微信登录
  def self.wechat_login!(params = {})
    new(login_params: params, login_type: :wechat).call
  end

  private

  # 模拟登录逻辑
  def mock_login
    # 处理嵌套 JSON 参数或平铺参数
    # 优先使用顶级参数，如果没有则使用嵌套的user参数
    openid = login_params[:openid] || login_params.dig(:user, :wx_openid) || login_params.dig(:user, :openid) || "test_dhh_001"
    nickname = login_params[:nickname] || login_params.dig(:user, :nickname) || "DHH"
    avatar_url = login_params[:avatar_url] || login_params.dig(:user, :avatar_url)

    # 查找或创建用户
    @user = User.find_or_create_by(wx_openid: openid) do |u|
      u.nickname = nickname
      # 如果没有提供头像，生成一个随机头像
      u.avatar_url = avatar_url.presence || AvatarGeneratorService.generate_themed_avatar(
        nickname: nickname,
        user_id: openid
      )
    end

    # 如果用户已存在但没有头像，也生成一个
    if @user.avatar_url.blank? || @user.avatar_url.include?('example.com/avatar.jpg')
      @user.update!(
        avatar_url: AvatarGeneratorService.generate_themed_avatar(
          nickname: @user.nickname,
          user_id: @user.id
        )
      )
    end

    generate_token_response
  end

  # 微信登录逻辑
  def wechat_login
    code = login_params[:code]
    return failure!("缺少 code 参数") unless code

    # 获取小程序传递的用户信息
    user_info = login_params[:user_info] || {}
    openid = login_params[:openid] || user_info[:openid]
    unionid = login_params[:unionid] || user_info[:unionid]
    nickname = login_params[:nickname] || user_info[:nickname]
    avatar_url = login_params[:avatar_url] || login_params[:avatarUrl] || user_info[:avatar_url] || user_info[:avatarUrl]

    # 如果没有直接提供用户信息，尝试调用微信API获取
    if openid.blank? && code.present?
      wechat_result = fetch_wechat_openid(code)

      # 如果是测试环境且有用户信息，生成测试openid
      if wechat_result.nil? && user_info.present?
        openid = "test_wechat_#{Time.current.to_i}_#{rand(1000)}"
        Rails.logger.info "使用测试openid: #{openid} for user: #{user_info[:nickname]}"
      else
        return failure!("微信登录失败") unless wechat_result
        openid = wechat_result[:openid]
        unionid = wechat_result[:unionid]
      end
    end

    return failure!("无法获取用户标识") unless openid

    # 查找或创建用户
    @user = User.find_or_create_by(wx_openid: openid) do |u|
      u.wx_unionid = unionid if unionid.present?
      u.nickname = nickname.presence || "用户#{rand(1000..9999)}"
      # 优先使用微信提供的真实头像，如果没有则生成默认头像
      u.avatar_url = if avatar_url.present?
                      avatar_url
                    else
                      AvatarGeneratorService.generate_themed_avatar(
                        nickname: u.nickname,
                        user_id: openid
                      )
                    end
    end

    # 如果用户已存在但头像为空或使用了默认头像，且当前提供了新头像，则更新
    if avatar_url.present? && (@user.avatar_url.blank? || @user.avatar_url.include?('example.com/avatar.jpg'))
      update_attrs = { avatar_url: avatar_url }
      update_attrs[:nickname] = nickname if nickname.present?
      @user.update!(update_attrs)
    end

    generate_token_response
  end

  # 生成Token响应
  def generate_token_response
    access_token = @user.generate_jwt_token
    refresh_token = @user.generate_refresh_token

    response_data = {
      access_token: access_token,
      refresh_token: refresh_token,
      user: user_data(@user)
    }

    success!(response_data)
  end

  # 格式化用户数据 - 返回字符串键格式用于API响应
  def user_data(user)
    {
      'id' => user.id,
      'nickname' => user.nickname,
      'wx_openid' => user.wx_openid,
      'avatar_url' => user.avatar_url,
      'phone' => user.phone
    }
  end

  # 调用微信API获取openid（简化版本）
  def fetch_wechat_openid(code)
    # TODO: 配置 credentials 后实现
    # app_id = Rails.application.credentials.wechat[:app_id]
    # app_secret = Rails.application.credentials.wechat[:app_secret]
    # url = "https://api.weixin.qq.com/sns/jscode2session"
    # response = HTTParty.get(url, query: {
    #   appid: app_id,
    #   secret: app_secret,
    #   js_code: code,
    #   grant_type: "authorization_code"
    # })
    #
    # if response["openid"]
    #   { openid: response["openid"], unionid: response["unionid"] }
    # else
    #   nil
    # end

    # 暂时返回 nil，提示用户配置 credentials
    nil
  end
end