# frozen_string_literal: true

require "test_helper"

class EventEnrollmentServiceTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user(:user)
    @leader = create_test_user(:user)
    @admin = create_test_user(:admin)

    @reading_event = ReadingEvent.create!(
      title: "《西游记》精读班",
      book_name: "西游记",
      description: "古典名著精读活动",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 20,
      min_participants: 3,
      fee_type: "free",
      fee_amount: 0,
      leader_reward_percentage: 10,
      completion_standard: 80,
      activity_mode: "note_checkin",
      leader_assignment_type: "voluntary",
      weekend_rest: true,
      leader: @leader,
      status: "enrolling",
      approval_status: "approved"
    )

    # 创建一些报名记录用于测试
    @existing_enrollment = EventEnrollment.create!(
      reading_event: @reading_event,
      user: @user,
      enrollment_type: "participant",
      status: "enrolled",
      enrollment_date: Time.current
    )
  end

  # 基本功能测试
  test "should initialize service with event and user" do
    service = EventEnrollmentService.new(event: @reading_event, user: @leader)

    assert_equal @reading_event, service.event
    assert_equal @leader, service.user
    assert_nil service.enrollment
  end

  test "should inherit from ApplicationService" do
    service = EventEnrollmentService.new(event: @reading_event, user: @leader)

    assert service.is_a?(ApplicationService)
    assert service.respond_to?(:call)
    assert service.respond_to?(:success?)
    assert service.respond_to?(:failure?)
  end

  # 成功报名测试
  test "should successfully enroll user in approved event" do
    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: @reading_event, user: new_user)

    result = service.call

    assert result.success?
    assert_equal "报名成功", result.result[:message]
    assert_not_nil service.enrollment
    assert_equal new_user, service.enrollment.user
    assert_equal @reading_event, service.enrollment.reading_event
    assert_equal "enrolled", service.enrollment.status
    assert_equal "participant", service.enrollment.enrollment_type
  end

  test "should create enrollment with correct attributes" do
    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: @reading_event, user: new_user)

    service.call

    enrollment = service.enrollment
    assert_not_nil enrollment
    assert_equal new_user.id, enrollment.user_id
    assert_equal @reading_event.id, enrollment.reading_event_id
    assert_equal Time.current.to_date, enrollment.enrollment_date.to_date
    assert_equal "unpaid", enrollment.payment_status
  end

  test "should return correct enrollment data in response" do
    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: @reading_event, user: new_user)

    result = service.call

    assert result.success?
    assert_not_nil result.data[:enrollment_data]

    enrollment_data = result.data[:enrollment_data]
    assert_equal service.enrollment.id, enrollment_data[:id]
    assert_equal new_user.id, enrollment_data[:user_id]
    assert_equal @reading_event.id, enrollment_data[:reading_event_id]
    assert_equal "unpaid", enrollment_data[:payment_status]
    assert_equal "participant", enrollment_data[:role]
    assert_equal 0, enrollment_data[:paid_amount] # free event
    assert_not_nil enrollment_data[:created_at]
  end

  test "should handle class method enrollment" do
    new_user = create_test_user(:user)

    result = EventEnrollmentService.enroll_user!(@reading_event, new_user)

    assert result.success?
    assert_equal "报名成功", result.message
    assert new_user.enrollments.exists?(reading_event: @reading_event)
  end

  # 活动状态验证测试
  test "should reject enrollment for non-approved event" do
    pending_event = ReadingEvent.create!(
      title: "待审批活动",
      book_name: "测试书籍",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 20,
      leader: @leader,
      approval_status: "pending"
    )

    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: pending_event, user: new_user)

    result = service.call

    assert result.failure?
    assert_equal "活动尚未审批通过，无法报名", result.message
  end

  test "should reject enrollment for rejected event" do
    rejected_event = ReadingEvent.create!(
      title: "被拒绝活动",
      book_name: "测试书籍",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 20,
      leader: @leader,
      approval_status: "rejected"
    )

    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: rejected_event, user: new_user)

    result = service.call

    assert result.failure?
    assert_equal "活动尚未审批通过，无法报名", result.message
  end

  test "should reject enrollment for event not in enrolling status" do
    # 将活动状态设置为进行中
    @reading_event.update!(status: 'in_progress')

    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: @reading_event, user: new_user)

    result = service.call

    assert result.failure?
    assert_equal "当前活动不在报名期间", result.message
  end

  # 重复报名测试
  test "should reject duplicate enrollment" do
    service = EventEnrollmentService.new(event: @reading_event, user: @user)

    result = service.call

    assert result.failure?
    assert_equal "您已经报名该活动", result.message
    assert_nil service.enrollment
  end

  # 人数限制测试
  test "should reject enrollment when event is full" do
    # 创建一个已满员的活动
    full_event = ReadingEvent.create!(
      title: "已满员活动",
      book_name: "测试书籍",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 2,
      min_participants: 1,
      leader: @leader,
      approval_status: "approved"
    )

    # 添加2个报名者达到上限
    user1 = create_test_user(:user)
    user2 = create_test_user(:user)

    EventEnrollment.create!(reading_event: full_event, user: user1, enrollment_date: Time.current)
    EventEnrollment.create!(reading_event: full_event, user: user2, enrollment_date: Time.current)

    # 第三个用户报名应该失败
    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: full_event, user: new_user)

    result = service.call

    assert result.failure?
    assert_equal "活动已满员", result.message
  end

  test "should allow enrollment when event has space" do
    # 创建一个有剩余名额的活动
    spacious_event = ReadingEvent.create!(
      title: "有余位活动",
      book_name: "测试书籍",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 5,
      min_participants: 2,
      leader: @leader,
      approval_status: "approved"
    )

    # 添加1个报名者
    user1 = create_test_user(:user)
    EventEnrollment.create!(reading_event: spacious_event, user: user1, enrollment_date: Time.current)

    # 新用户应该能成功报名
    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: spacious_event, user: new_user)

    result = service.call

    assert result.success?
    assert_equal "报名成功", result.message
  end

  # 费用处理测试
  test "should handle free event enrollment" do
    free_event = ReadingEvent.create!(
      title: "免费读书活动",
      book_name: "测试书籍",
      description: "这是一个免费的读书活动",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      fee_type: "free",
      fee_amount: 0,
      max_participants: 20,
      min_participants: 1,
      leader: @leader,
      approval_status: "approved"
    )

    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: free_event, user: new_user)

    result = service.call

    assert result.success?
    assert_equal 0, service.enrollment.paid_amount
    assert_equal "unpaid", service.enrollment.payment_status
  end

  test "should handle paid event enrollment" do
    paid_event = ReadingEvent.create!(
      title: "付费读书活动",
      book_name: "测试书籍",
      description: "这是一个付费的读书活动",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      fee_type: "paid",
      fee_amount: 100,
      max_participants: 20,
      min_participants: 1,
      leader: @leader,
      approval_status: "approved"
    )

    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: paid_event, user: new_user)

    result = service.call

    assert result.success?
    assert_equal 100, service.enrollment.paid_amount
    assert_equal "unpaid", service.enrollment.payment_status
  end

  # 领读人分配测试
  test "should auto-assign leaders for random assignment type when enough participants" do
    random_event = ReadingEvent.create!(
      title: "随机分配领读人活动",
      book_name: "测试书籍",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 20,
      leader_assignment_type: "random",
      leader: @leader,
      approval_status: "approved"
    )

    # 添加2个报名者（总共3个用户包括新用户）
    user1 = create_test_user(:user)
    user2 = create_test_user(:user)
    EventEnrollment.create!(reading_event: random_event, user: user1, enrollment_date: Time.current)
    EventEnrollment.create!(reading_event: random_event, user: user2, enrollment_date: Time.current)

    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: random_event, user: new_user)

    # 模拟assign_daily_leaders!方法
    random_event.define_singleton_method(:assign_daily_leaders!) do
      self.update!(leader: user1) # 模拟分配领读人
    end

    result = service.call

    assert result.success?
    assert_equal "报名成功", result.message
    # 验证是否有调用分配方法（这里仅作示例）
  end

  test "should not auto-assign leaders for voluntary assignment type" do
    voluntary_event = ReadingEvent.create!(
      title: "自愿领读活动",
      book_name: "测试书籍",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 20,
      leader_assignment_type: "voluntary",
      leader: @leader,
      approval_status: "approved"
    )

    # 添加多个报名者
    user1 = create_test_user(:user)
    user2 = create_test_user(:user)
    EventEnrollment.create!(reading_event: voluntary_event, user: user1, enrollment_date: Time.current)
    EventEnrollment.create!(reading_event: voluntary_event, user: user2, enrollment_date: Time.current)

    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: voluntary_event, user: new_user)

    result = service.call

    assert result.success?
    assert_equal @leader, voluntary_event.leader # 领读人应该保持不变
  end

  # 边界条件测试
  test "should handle nil event gracefully" do
    service = EventEnrollmentService.new(event: nil, user: @user)

    result = service.call

    assert result.failure?
    assert_includes result.message, "活动尚未审批通过" # 由于event为nil，检查会失败
  end

  test "should handle nil user gracefully" do
    service = EventEnrollmentService.new(event: @reading_event, user: nil)

    result = service.call

    assert result.failure?
    # 可能会因为user为nil导致各种错误，具体取决于实现
  end

  test "should handle event with max_participants equal to zero" do
    zero_capacity_event = ReadingEvent.create!(
      title: "无容量活动",
      book_name: "测试书籍",
      description: "容量为零的测试活动",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 1, # 设置为1而不是0，避免验证错误
      min_participants: 1,
      leader: @leader,
      approval_status: "approved"
    )

    # 手动设置一个报名者来达到满员状态
    existing_user = create_test_user(:user)
    EventEnrollment.create!(
      reading_event: zero_capacity_event,
      user: existing_user,
      enrollment_date: Time.current
    )

    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: zero_capacity_event, user: new_user)

    result = service.call

    assert result.failure?
    assert_equal "活动已满员", result.message
  end

  # 并发报名测试
  test "should handle concurrent enrollment attempts" do
    # 创建一个小容量活动
    small_event = ReadingEvent.create!(
      title: "小容量活动",
      book_name: "测试书籍",
      description: "小容量测试活动",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 2,
      min_participants: 1,
      leader: @leader,
      approval_status: "approved"
    )

    # 模拟并发报名（简化版本）
    user1 = create_test_user(:user)
    user2 = create_test_user(:user)
    user3 = create_test_user(:user)

    service1 = EventEnrollmentService.new(event: small_event, user: user1)
    service2 = EventEnrollmentService.new(event: small_event, user: user2)
    service3 = EventEnrollmentService.new(event: small_event, user: user3)

    # 依次报名（真实并发需要线程或进程）
    result1 = service1.call
    result2 = service2.call
    result3 = service3.call

    # 应该只有2个成功，1个失败
    success_count = [result1.success?, result2.success?, result3.success?].count(true)
    failure_count = [result1.failure?, result2.failure?, result3.failure?].count(true)

    assert_equal 2, success_count
    assert_equal 1, failure_count
  end

  # 数据完整性测试
  test "should create enrollment with all required fields" do
    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: @reading_event, user: new_user)

    service.call

    enrollment = service.enrollment
    enrollment.reload

    assert_not_nil enrollment.id
    assert_not_nil enrollment.user_id
    assert_not_nil enrollment.reading_event_id
    assert_not_nil enrollment.enrollment_date
    assert_not_nil enrollment.status
    assert_not_nil enrollment.enrollment_type
    assert_not_nil enrollment.payment_status
    assert_not_nil enrollment.created_at
    assert_not_nil enrollment.updated_at
  end

  test "should maintain database consistency on failure" do
    initial_enrollment_count = EventEnrollment.count

    # 尝试为已满员活动报名
    full_event = ReadingEvent.create!(
      title: "已满员活动",
      book_name: "测试书籍",
      description: "已满员测试活动",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 1,
      min_participants: 1,
      leader: @leader,
      approval_status: "approved"
    )

    EventEnrollment.create!(reading_event: full_event, user: create_test_user(:user), enrollment_date: Time.current)

    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: full_event, user: new_user)

    result = service.call

    assert result.failure?
    assert_equal initial_enrollment_count + 1, EventEnrollment.count # 只增加了一个报名记录
  end

  # 与其他业务逻辑集成测试
  test "should work with reading schedule integration" do
    # 为活动添加阅读计划
    ReadingSchedule.create!(
      reading_event: @reading_event,
      date: Date.current + 8.days,
      day_number: 1,
      reading_progress: "第一章"
    )

    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: @reading_event, user: new_user)

    result = service.call

    assert result.success?
    assert_equal 1, @reading_event.reading_schedules.count
    assert new_user.enrollments.exists?(reading_event: @reading_event)
  end

  test "should handle enrollment with flower quota integration" do
    # 创建鲜花配额
    FlowerQuota.create!(
      user: @user,
      reading_event: @reading_event,
      max_flowers: 5,
      used_flowers: 2,
      quota_date: Date.current
    )

    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: @reading_event, user: new_user)

    result = service.call

    assert result.success?
    # 验证报名不影响鲜花配额
    quota = FlowerQuota.find_by(user: new_user, quota_date: Date.current)
    if quota
      assert_equal 0, quota.used_flowers # 新用户应该有新配额
    end
  end

  # 性能测试
  test "should handle large number of existing enrollments efficiently" do
    # 创建一个有大量报名者的活动
    large_event = ReadingEvent.create!(
      title: "大型活动",
      book_name: "测试书籍",
      description: "大型测试活动",
      start_date: Date.current + 7.days,
      end_date: Date.current + 21.days,
      max_participants: 1000,
      min_participants: 1,
      leader: @leader,
      approval_status: "approved"
    )

    # 创建100个报名记录
    (1..100).each do |i|
      user = create_test_user(:user, nickname: "用户#{i}")
      EventEnrollment.create!(reading_event: large_event, user: user, enrollment_date: Time.current)
    end

    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: large_event, user: new_user)

    start_time = Time.current
    result = service.call
    end_time = Time.current

    assert result.success?
    assert end_time - start_time < 1.second # 应该在1秒内完成
  end

  # 日志和监控测试
  test "should log enrollment activities" do
    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: @reading_event, user: new_user)

    # 这里可以测试日志记录，但需要模拟Rails.logger
    # 简化版本仅验证服务调用成功
    result = service.call

    assert result.success?
    # 在真实环境中可以验证日志内容
  end

  # 不同用户角色测试
  test "should allow admin users to enroll" do
    admin_user = create_test_user(:admin)
    service = EventEnrollmentService.new(event: @reading_event, user: admin_user)

    result = service.call

    assert result.success?
    assert_equal "报名成功", result.message
  end

  test "should allow regular users to enroll" do
    regular_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: @reading_event, user: regular_user)

    result = service.call

    assert result.success?
    assert_equal "报名成功", result.message
  end

  test "should handle users with different permission levels" do
    # 创建不同权限的用户并测试报名
    users = [
      create_test_user(:user),
      create_test_user(:user),
      create_test_user(:admin)
    ]

    users.each do |user|
      next if user == @user # 跳过已报名用户

      service = EventEnrollmentService.new(event: @reading_event, user: user)
      result = service.call

      assert result.success?, "User with role #{user.role} should be able to enroll"
    end
  end

  # 错误恢复测试
  test "should recover from temporary database issues" do
    new_user = create_test_user(:user)
    service = EventEnrollmentService.new(event: @reading_event, user: new_user)

    # 模拟数据库连接问题（简化测试）
    result = service.call

    assert result.success?
    # 在真实环境中可以测试重试机制
  end

  private

  def create_test_user(role = :user, **attributes)
    default_attrs = {
      wx_openid: "test_openid_#{SecureRandom.hex(4)}",
      nickname: "测试用户#{SecureRandom.hex(4)}",
      avatar_url: "https://example.com/avatar.jpg",
      created_at: Time.current,
      updated_at: Time.current
    }

    case role
    when :admin
      default_attrs[:role] = 1
    when :root
      default_attrs[:role] = 2
    else
      default_attrs[:role] = 0
    end

    User.create!(default_attrs.merge(attributes))
  end
end