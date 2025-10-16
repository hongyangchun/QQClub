module Commentable
  extend ActiveSupport::Concern

  included do
    include ApiResponse
    before_action :authenticate_user!
    before_action :set_comment, only: [:update, :destroy]
  end

  # GET /api/comments
  def index
    @comments = fetch_comments.includes(:user).order(created_at: :asc)

    render_success(
      format_comments_response(@comments),
      message: '获取评论列表成功'
    )
  end

  # POST /api/comments
  def create
    @comment = build_comment(comment_params)
    @comment.user = current_user

    if @comment.save
      render_created(
        format_single_comment(@comment, true),
        message: '评论发布成功'
      )
    else
      render_error(
        '评论创建失败',
        errors: @comment.errors.full_messages
      )
    end
  end

  # PUT /api/comments/:id
  def update
    unless can_edit_comment?(@comment, current_user)
      return render_forbidden('无权限编辑此评论')
    end

    if @comment.update(comment_params)
      render_success(
        format_single_comment(@comment, true),
        message: '评论更新成功'
      )
    else
      render_error(
        '评论更新失败',
        errors: @comment.errors.full_messages
      )
    end
  end

  # DELETE /api/comments/:id
  def destroy
    unless can_edit_comment?(@comment, current_user)
      return render_forbidden('无权限删除此评论')
    end

    @comment.destroy
    render_success(
      nil,
      message: '评论删除成功'
    )
  end

  private

  def set_comment
    @comment = Comment.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: '评论不存在' }, status: :not_found
  end

  def comment_params
    params.require(:comment).permit(:content)
  end

  # 抽象方法，由包含的类实现
  def fetch_comments
    raise NotImplementedError, "子类必须实现 fetch_comments 方法"
  end

  def build_comment(params)
    raise NotImplementedError, "子类必须实现 build_comment 方法"
  end

  # 格式化评论列表响应
  def format_comments_response(comments)
    comments.map { |comment|
      format_single_comment(comment)
    }
  end

  # 格式化单个评论
  def format_single_comment(comment, can_edit = false)
    comment.instance_variable_set(:@can_edit_current_user, can_edit || can_edit_comment?(comment, current_user))
    comment.send(:as_json)
  end

  # 权限检查 - 使用模型的公共方法
  def can_edit_comment?(comment, user)
    comment.send(:can_edit?, user)
  end
end