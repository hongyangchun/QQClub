# frozen_string_literal: true

# PostManagementService - 帖子管理服务
# 负责帖子的创建、更新、删除、隐藏/显示等业务逻辑
class PostManagementService < ApplicationService
  attr_reader :post, :user, :action, :post_params

  def initialize(post:, user:, action:, post_params: {})
    super()
    @post = post
    @user = user
    @action = action
    @post_params = post_params
  end

  # 主要调用方法
  def call
    handle_errors do
      case action
      when :create
        create_post
      when :update
        update_post
      when :delete
        delete_post
      when :pin
        pin_post
      when :unpin
        unpin_post
      when :hide
        hide_post
      when :unhide
        unhide_post
      else
        failure!("不支持的操作: #{action}")
      end
    end
    self  # 返回service实例
  end

  # 类方法：创建帖子
  def self.create_post!(user, params)
    new(post: nil, user: user, action: :create, post_params: params).call
  end

  # 类方法：更新帖子
  def self.update_post!(post, user, params)
    new(post: post, user: user, action: :update, post_params: params).call
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
  def self.hide_post!(post, user)
    new(post: post, user: user, action: :hide).call
  end

  # 类方法：显示帖子
  def self.unhide_post!(post, user)
    new(post: post, user: user, action: :unhide).call
  end

  private

  # 创建帖子
  def create_post
    return failure!("用户不能为空") unless user

    new_post = user.posts.new(post_params)

    if new_post.save
      success!({
        message: "帖子创建成功",
        post: post_data(new_post)
      })
    else
      failure!(new_post.errors.full_messages)
    end
  end

  # 更新帖子
  def update_post
    return failure!("帖子不能为空") unless post
    return failure!("用户不能为空") unless user

    # 检查编辑权限
    unless post.can_edit?(user)
      return failure!("无权限编辑此帖子")
    end

    if post.update(post_params)
      success!({
        message: "帖子更新成功",
        post: post_data(post)
      })
    else
      failure!(post.errors.full_messages)
    end
  end

  # 删除帖子
  def delete_post
    return failure!("帖子不能为空") unless post
    return failure!("用户不能为空") unless user

    # 检查删除权限
    unless post.can_edit?(user)
      return failure!("无权限删除此帖子")
    end

    post.destroy

    success!({
      message: "帖子删除成功"
    })
  end

  # 置顶帖子
  def pin_post
    return failure!("帖子不能为空") unless post
    return failure!("用户不能为空") unless user

    # 检查置顶权限
    unless post.can_pin?(user)
      return failure!("无权限置顶此帖子")
    end

    post.pin!

    success!({
      message: "帖子已置顶",
      post: post_data(post)
    })
  end

  # 取消置顶帖子
  def unpin_post
    return failure!("帖子不能为空") unless post
    return failure!("用户不能为空") unless user

    # 检查置顶权限
    unless post.can_pin?(user)
      return failure!("无权限取消置顶此帖子")
    end

    post.unpin!

    success!({
      message: "帖子已取消置顶",
      post: post_data(post)
    })
  end

  # 隐藏帖子
  def hide_post
    return failure!("帖子不能为空") unless post
    return failure!("用户不能为空") unless user

    # 检查隐藏权限
    unless post.can_hide?(user)
      return failure!("无权限隐藏此帖子")
    end

    post.hide!

    success!({
      message: "帖子已隐藏",
      post: post_data(post)
    })
  end

  # 显示帖子
  def unhide_post
    return failure!("帖子不能为空") unless post
    return failure!("用户不能为空") unless user

    # 检查隐藏权限
    unless post.can_hide?(user)
      return failure!("无权限显示此帖子")
    end

    post.unhide!

    success!({
      message: "帖子已显示",
      post: post_data(post)
    })
  end

  # 格式化帖子数据 - 返回字符串键格式用于API响应
  def post_data(post)
    {
      'id' => post.id,
      'title' => post.title,
      'content' => post.content,
      'user_id' => post.user_id,
      'pinned' => post.pinned,
      'hidden' => post.hidden,
      'created_at' => post.created_at,
      'updated_at' => post.updated_at,
      'author_info' => {
        'id' => post.user.id,
        'nickname' => post.user.nickname,
        'avatar_url' => post.user.avatar_url,
        'role' => post.user.role_display_name
      },
      'can_edit_current_user' => false,
      'time_ago' => post.time_ago
    }
  end
end