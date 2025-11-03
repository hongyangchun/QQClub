# frozen_string_literal: true

# 测试用的简化JWT服务
class JwtService
  class << self
    def encode(payload)
      # 在测试环境中使用简单的编码
      payload.merge!({ exp: 1.hour.from_now.to_i })
      Base64.urlsafe_encode64(payload.to_json)
    end

    def decode(token)
      # 在测试环境中使用简单的解码
      payload_json = Base64.urlsafe_decode64(token)
      payload = JSON.parse(payload_json)

      # 检查过期时间
      return nil if payload['exp'] && Time.current.to_i > payload['exp']

      payload
    rescue
      nil
    end
  end
end