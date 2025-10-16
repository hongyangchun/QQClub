module Api
  class CheckInCommentsController < Api::ApplicationController
    include Commentable

    before_action :set_check_in, only: [:index, :create]

    private

    def fetch_comments
      @check_in.comments
    end

    def build_comment(params)
      comment = @check_in.comments.new(params)
      # 打卡评论不需要post_id
      comment.post_id = nil
      comment
    end

    def format_single_comment(comment, can_edit = false)
      # 为打卡评论使用专门的JSON格式，保持兼容性
      {
        id: comment.id,
        content: comment.content,
        created_at: comment.created_at,
        updated_at: comment.updated_at,
        author_info: {
          id: comment.user.id,
          nickname: comment.user.nickname,
          avatar_url: comment.user.avatar_url
        },
        can_edit_current_user: can_edit || can_edit_comment?(comment, current_user)
      }
    end

    def set_check_in
      @check_in = CheckIn.find(params[:check_in_id])
    rescue ActiveRecord::RecordNotFound
      render_not_found('打卡不存在')
    end
  end
end