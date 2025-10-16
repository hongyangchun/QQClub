module Api
  class AuthController < Api::ApplicationController
    before_action :authenticate_user!, only: [:me, :update_profile]

    # 引入Service
    def authentication_service
      AuthenticationService
    end

    # 模拟登录（测试用）
    def mock_login
      # 使用AuthenticationService处理模拟登录
      service_result = authentication_service.mock_login!(params.to_unsafe_h)

      if service_result.success?
        render json: service_result.result
      else
        render json: { error: service_result.first_error }, status: :unprocessable_entity
      end
    end

    # 微信登录（生产用）
    def login
      # 使用AuthenticationService处理微信登录
      service_result = authentication_service.wechat_login!(params.to_unsafe_h)

      if service_result.success?
        render json: service_result.result
      else
        error_message = service_result.first_error
        status_code = error_message.include?("code") ? :bad_request : :unauthorized
        render json: { error: error_message }, status: status_code
      end
    end

    # 获取当前用户信息
    def me
      render json: {
        user: {
          id: current_user.id,
          wx_openid: current_user.wx_openid,
          nickname: current_user.nickname,
          avatar_url: current_user.avatar_url,
          phone: current_user.phone
        }
      }
    end

    # 更新用户资料
    def update_profile
      if current_user.update(profile_params)
        render json: {
          message: "更新成功",
          user: {
            id: current_user.id,
            nickname: current_user.nickname,
            avatar_url: current_user.avatar_url,
            phone: current_user.phone
          }
        }
      else
        render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # fetch_wechat_openid方法已移至AuthenticationService

    def profile_params
      params.require(:user).permit(:nickname, :avatar_url, :phone)
    end
  end
end
