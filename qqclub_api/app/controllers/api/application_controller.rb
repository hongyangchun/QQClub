# frozen_string_literal: true

module Api
  class ApplicationController < ActionController::API
    # 简单的健康检查
    def health
      render json: {
        status: "ok",
        timestamp: Time.current.iso8601,
        environment: Rails.env,
        version: "1.0.0"
      }
    end

    private

    # 从 JWT token 中获取当前用户
    def current_user
      return unless auth_header_present?
      return unless auth_token_valid?

      user_id = decoded_jwt_token['user_id']
      @current_user ||= User.find_by(id: user_id)
    end

    # 检查是否需要用户认证
    def authenticate_user!
      render json: { error: "Unauthorized" }, status: :unauthorized unless current_user
    end

    private

    def auth_header_present?
      request.headers['Authorization'].present?
    end

    def auth_token_valid?
      auth_header = request.headers['Authorization']
      token = auth_header.split(' ').last if auth_header
      return false unless token

      decoded_token = User.decode_jwt_token(token)
      return false unless decoded_token

      # 检查 token 是否过期
      Time.current < Time.at(decoded_token['exp'])
    end

    def decoded_jwt_token
      auth_header = request.headers['Authorization']
      token = auth_header.split(' ').last if auth_header
      @decoded_jwt_token ||= User.decode_jwt_token(token) if token
    end
  end
end