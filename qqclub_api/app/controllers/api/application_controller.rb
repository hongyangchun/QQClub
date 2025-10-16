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
      return if current_user

      # 提供更详细的错误信息用于调试
      error_info = determine_auth_error
      Rails.logger.warn "认证失败: #{error_info[:reason]} - #{error_info[:details]}"

      render json: {
        error: error_info[:message],
        error_code: error_info[:code],
        details: Rails.env.development? ? error_info[:details] : nil
      }, status: :unauthorized
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

    # 分析认证失败的具体原因
    def determine_auth_error
      auth_header = request.headers['Authorization']

      # 1. 检查是否有Authorization头
      unless auth_header.present?
        return {
          code: 'MISSING_AUTH_HEADER',
          message: '缺少认证信息',
          reason: 'no_auth_header',
          details: '请求头中缺少Authorization字段'
        }
      end

      # 2. 检查Authorization格式
      unless auth_header.start_with?('Bearer ')
        return {
          code: 'INVALID_AUTH_FORMAT',
          message: '认证格式错误',
          reason: 'invalid_auth_format',
          details: "Authorization头格式应为'Bearer <token>'，当前为: #{auth_header[0..50]}..."
        }
      end

      # 3. 提取token
      token = auth_header.split(' ').last
      unless token.present?
        return {
          code: 'MISSING_TOKEN',
          message: '缺少认证令牌',
          reason: 'missing_token',
          details: 'Authorization头中缺少token部分'
        }
      end

      # 4. 检查token格式
      unless token.include?('.')
        return {
          code: 'INVALID_TOKEN_FORMAT',
          message: '令牌格式错误',
          reason: 'invalid_token_format',
          details: 'JWT token应包含三个部分，用点分隔'
        }
      end

      # 5. 尝试解码token
      begin
        decoded = User.decode_jwt_token(token)
        unless decoded
          return {
            code: 'INVALID_TOKEN',
            message: '令牌无效',
            reason: 'decode_failed',
            details: 'JWT token解码失败，可能被篡改或格式错误'
          }
        end

        # 6. 检查token是否过期
        exp_time = decoded['exp']
        if exp_time
          current_time = Time.current.to_i
          if current_time >= exp_time
            expired_time = Time.at(exp_time)
            return {
              code: 'TOKEN_EXPIRED',
              message: '令牌已过期',
              reason: 'token_expired',
              details: "Token已于#{expired_time.strftime('%Y-%m-%d %H:%M:%S')}过期"
            }
          end
        end

        # 7. 检查用户是否存在
        user_id = decoded['user_id']
        unless user_id
          return {
            code: 'INVALID_TOKEN_PAYLOAD',
            message: '令牌内容无效',
            reason: 'missing_user_id',
            details: 'Token中缺少user_id字段'
          }
        end

        user = User.find_by(id: user_id)
        unless user
          return {
            code: 'USER_NOT_FOUND',
            message: '用户不存在',
            reason: 'user_not_found',
            details: "Token中用户ID(#{user_id})对应的用户不存在"
          }
        end

        # 8. 检查用户状态（如果需要）
        # 这里可以添加用户状态检查逻辑

      rescue => e
        return {
          code: 'TOKEN_PROCESSING_ERROR',
          message: '令牌处理错误',
          reason: 'processing_error',
          details: "处理token时发生错误: #{e.message}"
        }
      end

      # 未知错误
      {
        code: 'UNKNOWN_AUTH_ERROR',
        message: '认证失败',
        reason: 'unknown',
        details: '认证过程中发生未知错误'
      }
    end
  end
end