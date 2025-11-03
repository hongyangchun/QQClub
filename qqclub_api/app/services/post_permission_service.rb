# frozen_string_literal: true

# PostPermissionService - 帖子权限检查服务
# 专门负责帖子相关操作的权限验证逻辑
class PostPermissionService < ApplicationService
  include ServiceInterface
  attr_reader :post, :user, :action

  def initialize(post:, user:, action:)
    super()
    @post = post
    @user = user
    @action = action
  end

  # 检查权限
  def call
    handle_errors do
      validate_permission_params
      check_specific_permission
    end
    self
  end

  # 快速权限检查方法（不使用handle_errors包装）
  def can_perform?
    validate_permission_params && check_specific_permission
  rescue
    false
  end

  private

  # 验证权限检查参数
  def validate_permission_params
    return failure!("用户不能为空") unless user
    return failure!("帖子不能为空") unless post
    return failure!("用户不存在") unless user.persisted?
    return failure!("帖子不存在") unless post.persisted?

    valid_actions = [:edit, :delete, :pin, :hide, :view, :comment]
    unless valid_actions.include?(action)
      return failure!("不支持的权限检查操作: #{action}")
    end

    true
  end

  # 检查具体权限
  def check_specific_permission
    result = case action
             when :edit
               can_edit?
             when :delete
               can_delete?
             when :pin
               can_pin?
             when :hide
               can_hide?
             when :view
               can_view?
             when :comment
               can_comment?
             else
               false
             end

    if result
      success!("权限检查通过")
    else
      failure!("权限不足")
    end
  end

  # 检查编辑权限
  def can_edit?
    # 帖子作者可以编辑自己的帖子
    return true if post.user_id == user.id

    # 管理员可以编辑任何帖子
    return true if user.admin?

    # 超级管理员可以编辑任何帖子
    return true if user.super_admin?

    false
  end

  # 检查删除权限
  def can_delete?
    # 帖子作者可以删除自己的帖子
    return true if post.user_id == user.id

    # 管理员可以删除任何帖子
    return true if user.admin?

    # 超级管理员可以删除任何帖子
    return true if user.super_admin?

    false
  end

  # 检查置顶权限
  def can_pin?
    # 只有管理员和超级管理员可以置顶帖子
    return true if user.admin?
    return true if user.super_admin?

    false
  end

  # 检查隐藏权限
  def can_hide?
    # 管理员和超级管理员可以隐藏帖子
    return true if user.admin?
    return true if user.super_admin?

    false
  end

  # 检查查看权限
  def can_view?
    # 已删除的帖子只有作者和管理员可以查看
    if post.deleted?
      return post.user_id == user.id || user.admin? || user.super_admin?
    end

    # 隐藏的帖子只有作者和管理员可以查看
    if post.hidden?
      return post.user_id == user.id || user.admin? || user.super_admin?
    end

    # 公开帖子所有人都可以查看
    true
  end

  # 检查评论权限
  def can_comment?
    # 不能对已删除的帖子评论
    return false if post.deleted?

    # 不能对隐藏的帖子评论（除非是作者或管理员）
    if post.hidden?
      return post.user_id == user.id || user.admin? || user.super_admin?
    end

    # 其他情况都可以评论
    true
  end

  # 类方法：快速权限检查
  def self.can_edit?(post, user)
    new(post: post, user: user, action: :edit).can_perform?
  end

  def self.can_delete?(post, user)
    new(post: post, user: user, action: :delete).can_perform?
  end

  def self.can_pin?(post, user)
    new(post: post, user: user, action: :pin).can_perform?
  end

  def self.can_hide?(post, user)
    new(post: post, user: user, action: :hide).can_perform?
  end

  def self.can_view?(post, user)
    new(post: post, user: user, action: :view).can_perform?
  end

  def self.can_comment?(post, user)
    new(post: post, user: user, action: :comment).can_perform?
  end

  # 带缓存的权限检查方法
  def self.can_edit_cached?(post, user, cache_options = {})
    can_perform_cached?(:edit, post, user, cache_options)
  end

  def self.can_delete_cached?(post, user, cache_options = {})
    can_perform_cached?(:delete, post, user, cache_options)
  end

  def self.can_pin_cached?(post, user, cache_options = {})
    can_perform_cached?(:pin, post, user, cache_options)
  end

  def self.can_hide_cached?(post, user, cache_options = {})
    can_perform_cached?(:hide, post, user, cache_options)
  end

  def self.can_view_cached?(post, user, cache_options = {})
    can_perform_cached?(:view, post, user, cache_options)
  end

  def self.can_comment_cached?(post, user, cache_options = {})
    can_perform_cached?(:comment, post, user, cache_options)
  end

  # 批量权限检查 - 优化列表页面性能
  def self.batch_check_posts_permissions(post_ids, user_id, actions = [:edit, :delete, :pin, :hide, :comment])
    return {} if post_ids.blank? || user_id.blank?

    cache_keys = actions.product(post_ids).map do |action, post_id|
      "post_permission:#{action}:#{post_id}:#{user_id}"
    end

    # 尝试从缓存获取
    cached_results = Rails.cache.read_multi(*cache_keys)

    # 找出需要查询的权限
    uncached_permissions = []
    actions.each do |action|
      post_ids.each do |post_id|
        cache_key = "post_permission:#{action}:#{post_id}:#{user_id}"
        unless cached_results.key?(cache_key)
          uncached_permissions << { action: action, post_id: post_id, cache_key: cache_key }
        end
      end
    end

    # 批量查询并缓存未缓存的权限
    if uncached_permissions.any?
      batch_cache_permissions(uncached_permissions, user_id)
    end

    # 组织返回结果
    results = {}
    actions.each do |action|
      results[action] = {}
      post_ids.each do |post_id|
        cache_key = "post_permission:#{action}:#{post_id}:#{user_id}"
        results[action][post_id.to_i] = cached_results[cache_key] || false
      end
    end

    results
  end

  private

  # 通用缓存权限检查方法
  def self.can_perform_cached?(action, post, user, cache_options = {})
    return false unless post&.persisted? && user&.persisted?

    cache_key = "post_permission:#{action}:#{post.id}:#{user.id}"
    cache_options = {
      expires_in: cache_options[:expires_in] || 5.minutes,
      race_condition_ttl: 10.seconds
    }.merge(cache_options)

    Rails.cache.fetch(cache_key, cache_options) do
      new(post: post, user: user, action: action).can_perform?
    end
  end

  # 批量缓存权限检查结果
  def self.batch_cache_permissions(permissions, user_id)
    # 按action分组以优化数据库查询
    permissions_by_action = permissions.group_by { |p| p[:action] }

    permissions_by_action.each do |action, perms|
      post_ids = perms.map { |p| p[:post_id] }

      # 批量加载帖子和用户
      posts = Post.where(id: post_ids).includes(:user)
      user = User.find_by(id: user_id)
      next unless user

      # 批量检查权限
      perms.each do |perm|
        post = posts.find { |p| p.id == perm[:post_id] }
        next unless post

        result = new(post: post, user: user, action: action).can_perform?
        Rails.cache.write(perm[:cache_key], result, expires_in: 5.minutes)
      end
    end
  end
end