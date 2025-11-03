# frozen_string_literal: true

# DomainEventsService - 领域事件服务
# 负责管理领域事件的发布和订阅，解耦服务间的依赖关系
class DomainEventsService
  class << self
    # 发布事件
    def publish(event_name, payload = {})
      event = DomainEvent.new(event_name, payload)

      Rails.logger.info "发布领域事件: #{event_name} - #{payload.inspect}"

      # 同步执行订阅者
      ActiveSupport::Notifications.instrument("domain_event.#{event_name}", payload) do
        subscribers = find_subscribers(event_name)
        subscribers.each { |subscriber| subscriber.call(event) }
      end

      event
    end

    # 订阅事件
    def subscribe(event_name, subscriber_class = nil, &block)
      subscriber = if block_given?
                    block
                  elsif subscriber_class
                    if subscriber_class.respond_to?(:handle)
                      subscriber_class.method(:handle)
                    else
                      raise ArgumentError, "订阅者类必须实现handle方法"
                    end
                  else
                    raise ArgumentError, "必须提供订阅者类或代码块"
                  end

      subscribers[event_name] ||= []
      subscribers[event_name] << subscriber

      Rails.logger.info "注册事件订阅: #{event_name} -> #{subscriber_class || '匿名订阅者'}"
    end

    # 取消订阅
    def unsubscribe(event_name, subscriber)
      subscribers[event_name]&.delete(subscriber)
    end

    # 获取事件订阅者
    def subscribers_for(event_name)
      subscribers[event_name] || []
    end

    # 清除所有订阅者（主要用于测试）
    def clear_subscribers!
      @subscribers = {}
    end

    # 获取所有事件类型
    def event_types
      subscribers.keys
    end

    private

    def subscribers
      @subscribers ||= {}
    end

    def find_subscribers(event_name)
      subscribers[event_name] || []
    end
  end

  # 领域事件类
  class DomainEvent
    attr_reader :name, :payload, :timestamp

    def initialize(name, payload = {})
      @name = name
      @payload = payload.with_indifferent_access
      @timestamp = Time.current
    end

    def data(key = nil)
      if key
        @payload[key]
      else
        @payload
      end
    end

    def occurred_at
      @timestamp
    end

    def to_s
      "DomainEvent(#{name}, #{payload}, #{@timestamp})"
    end
  end
end