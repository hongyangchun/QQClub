module Authenticable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
  end

  private

  def authenticate_user!
    token = extract_token_from_header
    return render_unauthorized unless token

    decoded = User.decode_jwt_token(token)
    return render_unauthorized unless decoded

    @current_user = User.find_by(id: decoded[:user_id])
    render_unauthorized unless @current_user
  end

  def current_user
    @current_user
  end

  def extract_token_from_header
    header = request.headers["Authorization"]
    return nil unless header

    # 格式: "Bearer <token>"
    header.split(" ").last if header.start_with?("Bearer ")
  end

  def render_unauthorized
    render json: { error: "Unauthorized" }, status: :unauthorized
  end
end
