# frozen_string_literal: true

# 领域事件系统初始化
Rails.application.config.after_initialize do
  # 延迟加载订阅者类，避免启动时的加载顺序问题
  begin
    require_dependency 'event_subscribers/notification_event_subscriber'

    # 注册通知事件订阅者
    DomainEventsService.subscribe('flower.given', NotificationEventSubscriber)
    DomainEventsService.subscribe('flower.comment_created', NotificationEventSubscriber)
    DomainEventsService.subscribe('post.created', NotificationEventSubscriber)
    DomainEventsService.subscribe('post.updated', NotificationEventSubscriber)
    DomainEventsService.subscribe('post.moderated', NotificationEventSubscriber)
    DomainEventsService.subscribe('report.created', NotificationEventSubscriber)
    DomainEventsService.subscribe('report.processed', NotificationEventSubscriber)
    DomainEventsService.subscribe('event.enrollment.created', NotificationEventSubscriber)
    DomainEventsService.subscribe('event.approval.required', NotificationEventSubscriber)

    Rails.logger.info "领域事件订阅者初始化完成"
  rescue => e
    Rails.logger.error "领域事件订阅者初始化失败: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end