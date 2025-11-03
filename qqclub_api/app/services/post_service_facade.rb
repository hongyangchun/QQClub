# frozen_string_literal: true

# PostServiceFacade - 帖子服务门面
# 简化控制器层对帖子服务的调用，提供统一的接口
class PostServiceFacade < ApplicationService
  include ServiceInterface

  attr_reader :user, :current_user, :params

  def initialize(user:, current_user: nil, params: {})
    super()
    @user = user
    @current_user = current_user || user
    @params = params
  end

  def call
    handle_errors do
      validate_parameters
      execute_operation
    end
    self
  end

  # 类方法：创建帖子并返回格式化数据
  def self.create_with_data(user, params, current_user: nil)
    new(user: user, current_user: current_user, params: params).tap do |facade|
      facade.instance_variable_set(:@action, :create)
      facade.call
    end
  end

  # 类方法：更新帖子并返回格式化数据
  def self.update_with_data(post, user, params, current_user: nil)
    facade = new(user: user, current_user: current_user, params: params)
    facade.instance_variable_set(:@post, post)
    facade.instance_variable_set(:@action, :update)
    facade.call
    facade
  end

  # 类方法：删除帖子
  def self.delete_post(post, user, current_user: nil)
    facade = new(user: user, current_user: current_user)
    facade.instance_variable_set(:@post, post)
    facade.instance_variable_set(:@action, :delete)
    facade.call
    facade
  end

  # 类方法：置顶帖子
  def self.pin_post(post, user, current_user: nil)
    facade = new(user: user, current_user: current_user)
    facade.instance_variable_set(:@post, post)
    facade.instance_variable_set(:@action, :pin)
    facade.call
    facade
  end

  # 类方法：取消置顶帖子
  def self.unpin_post(post, user, current_user: nil)
    facade = new(user: user, current_user: current_user)
    facade.instance_variable_set(:@post, post)
    facade.instance_variable_set(:@action, :unpin)
    facade.call
    facade
  end

  private

  def validate_parameters
    case action
    when :create
      errors.add(:user, "用户不能为空") if user.blank?
      errors.add(:params, "创建参数不能为空") if params.blank?
      errors.add(:title, "标题不能为空") if params[:title].blank?
      errors.add(:content, "内容不能为空") if params[:content].blank?
    when :update, :delete, :pin, :unpin
      post = instance_variable_get(:@post)
      errors.add(:post, "帖子不能为空") if post.blank?
      errors.add(:user, "用户不能为空") if user.blank?
    end
  end

  def execute_operation
    case action
    when :create
      create_post_with_data
    when :update
      update_post_with_data
    when :delete
      delete_post_action
    when :pin, :unpin
      moderate_post_action(action)
    else
      failure!("不支持的操作")
    end
  end

  def create_post_with_data
    # 使用PostCreationService创建帖子
    creation_result = PostCreationService.new(user: user, post_params: params).call

    unless creation_result.success?
      return failure!(creation_result.error_messages)
    end

    post = creation_result.data[:post]

    # 发布帖子创建事件
    DomainEventsService.publish('post.created', {
      post: post,
      user: user
    })

    # 格式化帖子数据
    formatted_data = PostDataService.format_post(post, current_user: current_user)

    success!({
      post: formatted_data,
      message: "帖子创建成功"
    })
  end

  def update_post_with_data
    post = instance_variable_get(:@post)

    # 使用PostUpdateService更新帖子
    update_result = PostUpdateService.new(
      post: post,
      user: user,
      post_params: params
    ).call

    unless update_result.success?
      return failure!(update_result.error_messages)
    end

    # 发布帖子更新事件
    DomainEventsService.publish('post.updated', {
      post: post,
      user: user
    })

    # 格式化帖子数据
    formatted_data = PostDataService.format_post(post, current_user: current_user)

    success!({
      post: formatted_data,
      message: "帖子更新成功"
    })
  end

  def delete_post_action
    post = instance_variable_get(:@post)

    # 使用PostModerationService删除帖子
    deletion_result = PostModerationService.new(
      post: post,
      user: user,
      action: :delete
    ).call

    if deletion_result.success?
      # 发布帖子审核事件
      DomainEventsService.publish('post.moderated', {
        post: post,
        moderator: user,
        action: :delete,
        reason: params[:reason]
      })

      success!({ message: "帖子删除成功" })
    else
      failure!(deletion_result.error_messages)
    end
  end

  def moderate_post_action(moderation_action)
    post = instance_variable_get(:@post)

    # 使用PostModerationService进行管理操作
    moderation_result = PostModerationService.new(
      post: post,
      user: user,
      action: moderation_action,
      reason: params[:reason]
    ).call

    if moderation_result.success?
      # 发布帖子审核事件
      DomainEventsService.publish('post.moderated', {
        post: post,
        moderator: user,
        action: moderation_action,
        reason: params[:reason]
      })

      action_name = moderation_action == :pin ? "置顶" : "取消置顶"
      success!({ message: "帖子#{action_name}成功" })
    else
      failure!(moderation_result.error_messages)
    end
  end

  def action
    @action || :create
  end
end