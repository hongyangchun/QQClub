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
    avatar_url = login_params[:avatar_url] || login_params.dig(:user, :avatar_url) || "https://example.com/avatar.jpg"

    # 查找或创建用户
    @user = User.find_or_create_by(wx_openid: openid) do |u|
      u.nickname = nickname
      u.avatar_url = avatar_url
    end

    generate_token_response
  end

  # 微信登录逻辑
  def wechat_login
    code = login_params[:code]
    return failure!("缺少 code 参数") unless code

    # 调用微信 API 获取 openid
    wechat_result = fetch_wechat_openid(code)
    return failure!("微信登录失败") unless wechat_result

    # 查找或创建用户
    @user = User.find_or_create_by(wx_openid: wechat_result[:openid]) do |u|
      u.wx_unionid = wechat_result[:unionid]
      u.nickname = "用户#{rand(1000..9999)}"
    end

    generate_token_response
  end

  # 生成Token响应
  def generate_token_response
    token = @user.generate_jwt_token

    success!({
      token: token,
      user: user_data(@user)
    })
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