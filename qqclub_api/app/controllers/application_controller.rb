class ApplicationController < ActionController::API
  include Authenticable

  # API健康检查端点
  def health
    response_data = {
      status: "ok",
      timestamp: Time.current.iso8601,
      version: "1.0.0",
      environment: Rails.env
    }

    render json: response_data
  end

  private

  def check_database_status
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      "connected"
    rescue => e
      "error: #{e.message}"
    end
  end

  def check_permissions_status
    begin
      # 检查权限相关的关键组件
      status = {}

      # 检查User模型
      status[:user_model] = User.respond_to?(:any_admin?) ? "ok" : "missing_methods"

      # 检查AdminAuthorizable
      status[:admin_authorizable] = defined?(AdminAuthorizable) ? "ok" : "missing"

      # 检查角色枚举
      if User.respond_to?(:roles)
        status[:role_enums] = User.roles.keys.join(",")
      else
        status[:role_enums] = "not_defined"
      end

      status
    rescue => e
      { error: e.message }
    end
  end
end
