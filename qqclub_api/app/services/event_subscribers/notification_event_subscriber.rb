# frozen_string_literal: true

# NotificationEventSubscriber - 通知事件订阅者
# 监听各种领域事件并发送相应的通知
class NotificationEventSubscriber
  class << self
    # 处理领域事件
    def handle(event)
      case event.name
      when 'flower.given'
        handle_flower_given(event)
      when 'flower.comment_created'
        handle_flower_comment(event)
      when 'post.created'
        handle_post_created(event)
      when 'post.updated'
        handle_post_updated(event)
      when 'post.moderated'
        handle_post_moderated(event)
      when 'report.created'
        handle_report_created(event)
      when 'report.processed'
        handle_report_processed(event)
      when 'event.enrollment.created'
        handle_event_enrollment_created(event)
      when 'event.approval.required'
        handle_event_approval_required(event)
      else
        Rails.logger.warn "未知事件类型: #{event.name}"
      end
    rescue => e
      Rails.logger.error "处理事件失败 #{event.name}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end

    private

    # 处理小红花赠送事件
    def handle_flower_given(event)
      giver = event.data(:giver)
      recipient = event.data(:recipient)
      flower = event.data(:flower)

      return unless giver && recipient && flower

      NotificationService.send_flower_notification(recipient, giver, flower)
    end

    # 处理小红花评论事件
    def handle_flower_comment(event)
      flower = event.data(:flower)
      commenter = event.data(:commenter)
      comment = event.data(:comment)

      return unless flower && commenter && comment

      NotificationService.send_comment_notification(flower.recipient, commenter, comment)
    end

    # 处理帖子创建事件
    def handle_post_created(event)
      post = event.data(:post)
      user = event.data(:user)

      return unless post && user

      # 可以在这里发送帖子创建通知给关注者等
      # NotificationService.post_created_notification(post, user)
      Rails.logger.info "帖子创建事件: #{post.title} by #{user.nickname}"
    end

    # 处理帖子更新事件
    def handle_post_updated(event)
      post = event.data(:post)
      user = event.data(:user)

      return unless post && user

      # NotificationService.post_updated_notification(post, user)
      Rails.logger.info "帖子更新事件: #{post.title} by #{user.nickname}"
    end

    # 处理帖子审核事件
    def handle_post_moderated(event)
      post = event.data(:post)
      moderator = event.data(:moderator)
      action = event.data(:action)
      reason = event.data(:reason)

      return unless post && moderator

      case action
      when 'pin'
        # NotificationService.post_pinned_notification(post, moderator)
        Rails.logger.info "帖子置顶事件: #{post.title} by #{moderator.nickname}"
      when 'hide'
        # NotificationService.post_hidden_notification(post, moderator, reason)
        Rails.logger.info "帖子隐藏事件: #{post.title} by #{moderator.nickname}, 原因: #{reason}"
      when 'delete'
        # NotificationService.post_deleted_notification(post, moderator, reason)
        Rails.logger.info "帖子删除事件: #{post.title} by #{moderator.nickname}, 原因: #{reason}"
      end
    end

    # 处理举报创建事件
    def handle_report_created(event)
      report = event.data(:report)
      reporter = event.data(:reporter)

      return unless report && reporter

      # 发送通知给管理员
      NotificationService.send_bulk_notifications(
        User.where(role: %w[admin moderator]),
        reporter,
        report,
        'report_created',
        '新的举报',
        "用户 #{reporter.nickname} 提交了新的举报，请及时处理。"
      )
    end

    # 处理举报处理事件
    def handle_report_processed(event)
      report = event.data(:report)
      processor = event.data(:processor)
      action = event.data(:action)

      return unless report && processor

      # 通知举报者处理结果
      if report.user
        NotificationService.send_system_notification(
          report.user,
          '举报处理结果',
          "您提交的举报已被处理，处理结果：#{action}",
          actor: processor,
          notifiable: report
        )
      end
    end

    # 处理活动报名事件
    def handle_event_enrollment_created(event)
      enrollment = event.data(:enrollment)
      user = event.data(:user)
      event = event.data(:event)

      return unless enrollment && user && event

      # 通知活动组织者
      NotificationService.send_activity_update_notification(
        event.user, # 活动创建者
        user,
        event,
        'new_enrollment',
        "#{user.nickname} 报名了您的活动"
      )
    end

    # 处理活动审批需求事件
    def handle_event_approval_required(event)
      event = event.data(:event)
      submitter = event.data(:submitter)

      return unless event && submitter

      # 通知所有管理员审批
      NotificationService.send_bulk_notifications(
        User.where(role: 'admin'),
        submitter,
        event,
        'event_approval_required',
        '活动审批',
        "活动 #{event.title} 需要审批"
      )
    end
  end
end