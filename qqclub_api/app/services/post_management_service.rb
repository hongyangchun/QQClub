# frozen_string_literal: true

# PostManagementService - 帖子管理服务（重构版）
# 作为帖子相关服务的协调器，提供统一的接口
class PostManagementService < ApplicationService
  include ServiceInterface
  attr_reader :post, :user, :action, :params

  def initialize(post: nil, user:, action:, params: {})
    super()
    @post = post
    @user = user
    @action = action
    @params = params
  end

  # 主要调用方法
  def call
    handle_errors do
      validate_params
      execute_action
    end
    self
  end

  # 类方法：创建帖子
  def self.create_post!(user, params)
    new(user: user, action: :create, params: params).call
  end

  # 类方法：更新帖子
  def self.update_post!(post, user, params)
    new(post: post, user: user, action: :update, params: params).call
  end

  # 类方法：删除帖子
  def self.delete_post!(post, user)
    new(post: post, user: user, action: :delete).call
  end

  # 类方法：置顶帖子
  def self.pin_post!(post, user)
    new(post: post, user: user, action: :pin).call
  end

  # 类方法：取消置顶帖子
  def self.unpin_post!(post, user)
    new(post: post, user: user, action: :unpin).call
  end

  # 类方法：隐藏帖子
  def self.hide_post!(post, user, reason: nil)
    new(post: post, user: user, action: :hide, params: { reason: reason }).call
  end

  # 类方法：显示帖子
  def self.unhide_post!(post, user)
    new(post: post, user: user, action: :unhide).call
  end

  # 类方法：获取帖子数据
  def self.get_post_data(post, current_user: nil, options: {})
    PostDataService.format_post(post, current_user: current_user, options: options)
  end

  # 类方法：检查权限
  def self.check_permission(post, user, action)
    PostPermissionService.can_perform?(post, user, action)
  end

  private

  # 验证参数
  def validate_params
    return failure!("用户不能为空") unless user
    return failure!("用户不存在") unless user.persisted?

    case action
    when :create
      return failure!("创建参数不能为空") if params.blank?
    when :update, :delete, :pin, :unpin, :hide, :unhide
      return failure!("帖子不能为空") unless post
      return failure!("帖子不存在") unless post.persisted?
    else
      return failure!("不支持的操作: #{action}")
    end

    true
  end

  # 执行具体操作
  def execute_action
    result = case action
             when :create
               create_post
             when :update
               update_post
             when :delete
               delete_post
             when :pin
               moderate_post(:pin)
             when :unpin
               moderate_post(:unpin)
             when :hide
               moderate_post(:hide, reason: params[:reason])
             when :unhide
               moderate_post(:unhide)
             else
               failure!("不支持的操作: #{action}")
             end

    if result&.success?
      # 从子服务的结果中获取数据
      service_data = result.instance_variable_get(:@data)
      success!(service_data)
    else
      failure!(result&.errors || ["操作失败"])
    end
  end

  # 创建帖子
  def create_post
    PostCreationService.new(user: user, post_params: params).call
  end

  # 更新帖子
  def update_post
    PostUpdateService.new(post: post, user: user, post_params: params).call
  end

  # 删除帖子
  def delete_post
    PostModerationService.new(post: post, user: user, action: :delete).call
  end

  # 管理操作（置顶、隐藏等）
  def moderate_post(moderation_action, reason: nil)
    PostModerationService.new(
      post: post,
      user: user,
      action: moderation_action,
      reason: reason
    ).call
  end
end