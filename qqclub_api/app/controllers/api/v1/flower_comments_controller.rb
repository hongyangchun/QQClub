# frozen_string_literal: true

class Api::V1::FlowerCommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_flower

  # POST /api/flowers/:flower_id/comments
  def create
    result = FlowerCommentService.add_comment_to_flower(@flower, current_user, comment_params[:content])

    if result[:success]
      render json: result, status: :created
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  # GET /api/flowers/:flower_id/comments
  def index
    page = params[:page] || 1
    limit = params[:limit] || 10

    result = FlowerCommentService.get_flower_comments(@flower, page, limit, current_user)

    render json: result
  end

  # GET /api/flowers/:flower_id/comments/stats
  def stats
    result = FlowerCommentService.get_flower_comment_stats(@flower)

    render json: result
  end

  # DELETE /api/flowers/:flower_id/comments/:id
  def destroy
    comment = @flower.comments.find(params[:id])
    result = FlowerCommentService.delete_flower_comment(@flower, comment, current_user)

    if result[:success]
      render json: { message: result[:message] }
    else
      render json: { error: result[:error] }, status: :forbidden
    end
  end

  # DELETE /api/flowers/:flower_id/comments/batch
  def batch_destroy
    return render json: { error: '需要管理员权限' }, status: :forbidden unless current_user.any_admin?

    comment_ids = params[:comment_ids] || []
    result = FlowerCommentService.batch_delete_flower_comments(@flower, comment_ids, current_user)

    render json: result
  end

  # GET /api/flowers/:flower_id/comments/search
  def search
    keyword = params[:q] || params[:keyword]
    page = params[:page] || 1
    limit = params[:limit] || 10

    result = FlowerCommentService.search_flower_comments(@flower, keyword, page, limit, current_user)

    render json: result
  end

  private

  def set_flower
    @flower = Flower.find(params[:flower_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: '小红花不存在' }, status: :not_found
  end

  def comment_params
    params.require(:comment).permit(:content)
  end
end