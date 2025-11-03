# frozen_string_literal: true

require 'test_helper'

class DomainEventsServiceTest < ActiveSupport::TestCase
  def setup
    # 清除所有订阅者
    DomainEventsService.clear_subscribers!

    # 创建测试数据（不依赖fixtures）
    @user = User.create!(nickname: 'Test User', wx_openid: 'test_openid_1', role: 0)
    @other_user = User.create!(nickname: 'Admin User', wx_openid: 'test_openid_2', role: 2)
    @post = Post.create!(title: 'Test Post', content: 'Test content', user: @user)
  end

  def teardown
    # 清除所有订阅者
    DomainEventsService.clear_subscribers!
  end

  test "应该能够发布事件" do
    # 注册测试订阅者
    received_event = nil
    DomainEventsService.subscribe('test.event') do |event|
      received_event = event
    end

    # 发布事件
    payload = { user_id: @user.id, post_id: @post.id }
    event = DomainEventsService.publish('test.event', payload)

    # 验证事件发布
    assert_equal 'test.event', event.name
    assert_equal payload.stringify_keys, event.payload
    assert_not_nil event.timestamp

    # 验证订阅者接收到事件
    assert_not_nil received_event
    assert_equal event.name, received_event.name
    assert_equal event.payload, received_event.payload
  end

  test "应该能够订阅多个事件" do
    events_received = []

    # 注册多个事件的订阅者
    DomainEventsService.subscribe('flower.given') do |event|
      events_received << { type: 'flower.given', data: event.data }
    end

    DomainEventsService.subscribe('post.created') do |event|
      events_received << { type: 'post.created', data: event.data }
    end

    # 发布不同事件
    DomainEventsService.publish('flower.given', { giver: @user, recipient: @other_user })
    DomainEventsService.publish('post.created', { post: @post, user: @user })

    # 验证接收到所有事件
    assert_equal 2, events_received.length
    assert_equal 'flower.given', events_received[0][:type]
    assert_equal 'post.created', events_received[1][:type]
  end

  test "应该能够取消订阅" do
    call_count = 0

    # 注册订阅者
    subscriber = ->(event) { call_count += 1 }
    DomainEventsService.subscribe('test.event', &subscriber)

    # 发布事件
    DomainEventsService.publish('test.event', {})
    assert_equal 1, call_count

    # 取消订阅
    DomainEventsService.unsubscribe('test.event', subscriber)
    DomainEventsService.publish('test.event', {})

    # 验证不再接收到事件
    assert_equal 1, call_count
  end

  test "应该能够处理订阅者中的异常" do
    # 注册会抛出异常的订阅者
    DomainEventsService.subscribe('test.event') do |event|
      raise "测试异常"
    end

    # 注册正常的订阅者
    normal_received = false
    DomainEventsService.subscribe('test.event') do |event|
      normal_received = true
    end

    # 发布事件应该不会因为异常而中断
    assert_nothing_raised do
      DomainEventsService.publish('test.event', {})
    end

    # 验证正常订阅者仍然接收到事件
    assert normal_received
  end

  test "应该能够获取事件类型列表" do
    # 注册不同事件的订阅者
    DomainEventsService.subscribe('flower.given') {}
    DomainEventsService.subscribe('post.created') {}
    DomainEventsService.subscribe('post.updated') {}

    # 获取事件类型
    event_types = DomainEventsService.event_types

    assert_includes event_types, 'flower.given'
    assert_includes event_types, 'post.created'
    assert_includes event_types, 'post.updated'
    assert_equal 3, event_types.length
  end

  test "应该能够获取特定事件的订阅者" do
    subscriber1 = ->(event) {}
    subscriber2 = ->(event) {}

    DomainEventsService.subscribe('test.event', subscriber1)
    DomainEventsService.subscribe('test.event', subscriber2)
    DomainEventsService.subscribe('other.event', subscriber1)

    subscribers = DomainEventsService.subscribers_for('test.event')
    assert_equal 2, subscribers.length
    assert_includes subscribers, subscriber1
    assert_includes subscribers, subscriber2

    other_subscribers = DomainEventsService.subscribers_for('other.event')
    assert_equal 1, other_subscribers.length
    assert_includes other_subscribers, subscriber1
  end

  test "DomainEvent应该正确初始化" do
    payload = { user_id: @user.id, action: 'create' }
    event = DomainEventsService::DomainEvent.new('user.action', payload)

    assert_equal 'user.action', event.name
    assert_equal payload.stringify_keys, event.payload
    assert_not_nil event.timestamp
    assert_equal payload.stringify_keys, event.data
    assert_equal @user.id, event.data(:user_id)
  end

  test "DomainEvent应该能够转换为字符串" do
    payload = { user_id: @user.id }
    event = DomainEventsService::DomainEvent.new('test.event', payload)

    string_representation = event.to_s
    assert_includes string_representation, 'DomainEvent'
    assert_includes string_representation, 'test.event'
    assert_includes string_representation, payload.to_s
  end
end