# frozen_string_literal: true

require 'test_helper'

class FlowerServiceRefactoringTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user(:user)
    @other_user = create_test_user(:user)
    @event = create_test_reading_event(
      title: "测试阅读活动",
      book_name: "测试书籍",
      start_date: Date.today,
      end_date: Date.today + 7.days,
      status: 'in_progress'
    )
    @schedule = create_test_reading_schedule(
      reading_event: @event,
      day_number: 1,
      date: Date.today
    )
    # 确保用户参与活动
    @enrollment = EventEnrollment.create!(
      user: @user,
      reading_event: @event,
      enrollment_type: 'participant',
      status: 'enrolled',
      enrollment_date: Time.current
    )

    @other_enrollment = EventEnrollment.create!(
      user: @other_user,
      reading_event: @event,
      enrollment_type: 'participant',
      status: 'enrolled',
      enrollment_date: Time.current
    )

    # Create check-in manually to handle enrollment dependency
    @check_in = CheckIn.create!(
      user: @other_user,
      reading_schedule: @schedule,
      enrollment: @other_enrollment,
      content: "这是一个很棒的打卡内容，值得鼓励和支持！我们一起加油吧！今天读了很多内容，收获满满。通过阅读，我学到了很多新知识，对书中的观点有了更深入的理解。这个过程让我受益匪浅，也激发了我继续学习的热情。希望和大家一起成长，共同进步。",
      submitted_at: Time.current
    )
  end

  def teardown
    # 清理测试数据
    Flower.delete_all
    FlowerQuota.delete_all
    EventEnrollment.delete_all
    CheckIn.delete_all
    ReadingSchedule.delete_all
    ReadingEvent.delete_all
    User.delete_all
  end

  # ============================================================================
  # 测试 FlowerQuotaService
  # ============================================================================

  test "FlowerQuotaService should check flower giving eligibility correctly" do
    # 测试基本资格检查
    assert FlowerQuotaService.can_give_flower?(@user, @event, 1),
           "用户应该能够赠送小红花"

    # 测试数量限制
    assert FlowerQuotaService.can_give_flower?(@user, @event, 3),
           "用户应该能够赠送3朵小红花"

    # 测试超额情况
    assert_not FlowerQuotaService.can_give_flower?(@user, @event, 10),
              "用户不应该能够赠送超过限制的小红花"
  end

  test "FlowerQuotaService should provide daily quota info" do
    quota_info = FlowerQuotaService.get_user_daily_quota_info(@user, @event)

    assert quota_info.is_a?(Hash), "应该返回哈希数据"
    assert quota_info.key?(:user_id), "应该包含用户ID"
    assert quota_info.key?(:event_id), "应该包含活动ID"
    assert quota_info.key?(:used_flowers), "应该包含已使用数量"
    assert quota_info.key?(:max_flowers), "应该包含最大配额"
    assert quota_info.key?(:remaining_flowers), "应该包含剩余数量"
    assert_equal 0, quota_info[:used_flowers], "初始使用数量应该为0"
    assert_equal 3, quota_info[:max_flowers], "默认最大配额应该为3"
  end

  # ============================================================================
  # 测试 FlowerGivingService
  # ============================================================================

  test "FlowerGivingService should handle flower giving confirmation flow" do
    # 第一步：未确认时返回确认信息
    result = FlowerGivingService.give_flower_with_confirmation(
      @user, @other_user, @check_in,
      amount: 1, comment: "测试小红花",
      confirmed: false
    )

    assert result[:success], "应该返回成功状态"
    assert result[:require_confirmation], "应该要求确认"
    assert result[:confirmation_data], "应该包含确认数据"
    assert_equal "测试小红花", result[:confirmation_data][:comment]
  end

  test "FlowerGivingService should give flower when confirmed" do
    # 确认后赠送小红花
    result = FlowerGivingService.give_flower_with_confirmation(
      @user, @other_user, @check_in,
      amount: 1, comment: "确认赠送",
      confirmed: true
    )

    assert result[:success], "赠送应该成功"
    assert result[:flower], "应该返回小红花记录"
    assert_equal 1, result[:remaining_quota], "剩余配额应该减少"

    # 验证数据库记录
    flower = result[:flower]
    assert_equal @user, flower.giver, "赠送者应该正确"
    assert_equal @other_user, flower.recipient, "接收者应该正确"
    assert_equal @check_in, flower.check_in, "打卡记录应该正确"
    assert_equal "确认赠送", flower.comment, "评论应该正确"
  end

  test "FlowerGivingService should prevent self-giving" do
    result = FlowerGivingService.give_flower_with_confirmation(
      @user, @user, @check_in,
      confirmed: true
    )

    assert_not result[:success], "不应该允许给自己赠送小红花"
    assert_equal "不能给自己赠送小红花", result[:error]
  end

  test "FlowerGivingService should respect quota limits" do
    # 先用完配额
    3.times do |i|
      FlowerGivingService.give_flower_simple(
        @user, @other_user, @check_in,
        comment: "第#{i+1}朵小红花"
      )
    end

    # 再次尝试赠送应该失败
    result = FlowerGivingService.give_flower_simple(
      @user, @other_user, @check_in,
      comment: "超出配额"
    )

    assert_not result[:success], "配额用完后不应该能继续赠送"
    assert_includes result[:error], "配额已用完", "错误信息应该提到配额"
  end

  # ============================================================================
  # 测试 FlowerCertificateService
  # ============================================================================

  test "FlowerCertificateService should validate certificates" do
    # 创建一个测试证书
    certificate = FlowerCertificate.create!(
      user: @user,
      reading_event: @event,
      certificate_type: "flower_top1",
      rank: 1,
      total_flowers: 5,
      certificate_number: "TEST-001",
      issued_at: Time.current,
      expires_at: 1.year.from_now
    )

    result = FlowerCertificateService.validate_certificate(certificate.certificate_id)
    assert result[:valid], "有效证书应该通过验证"
    assert_equal certificate, result[:certificate], "应该返回正确的证书"
  end

  test "FlowerCertificateService should handle invalid certificates" do
    result = FlowerCertificateService.validate_certificate("INVALID-ID")
    assert_not result[:valid], "无效证书应该验证失败"
    assert_equal "证书不存在", result[:error]
  end

  # ============================================================================
  # 测试重构后的 FlowerIncentiveService 兼容性
  # ============================================================================

  test "FlowerIncentiveService should maintain backward compatibility" do
    # 测试原有方法是否仍然工作
    assert FlowerIncentiveService.can_give_flower?(@user, @event),
           "原方法应该仍然工作"

    quota_info = FlowerIncentiveService.get_user_daily_quota_info(@user, @event)
    assert quota_info.is_a?(Hash), "原方法应该返回正确格式"

    # 测试赠送流程
    result = FlowerIncentiveService.give_flower_with_confirmation(
      @user, @other_user, @check_in,
      confirmed: true, comment: "兼容性测试"
    )

    assert result[:success], "兼容的赠送方法应该工作"
    assert result[:flower], "应该创建小红花记录"
  end

  test "FlowerIncentiveService should provide new convenience methods" do
    # 测试新的便捷方法
    complete_status = FlowerIncentiveService.get_user_complete_status(@user, @event)

    assert complete_status.is_a?(Hash), "应该返回哈希"
    assert complete_status.key?(:quota_info), "应该包含配额信息"
    assert complete_status.key?(:can_give_flower), "应该包含赠送能力"
    assert complete_status.key?(:quota_warning), "应该包含配额警告"
    assert complete_status.key?(:certificates), "应该包含证书信息"
  end

  test "FlowerIncentiveService should provide smart giving suggestions" do
    # 为其他用户创建一些打卡记录
    other_check_in = CheckIn.create!(
      user: @other_user,
      reading_schedule: @schedule,
      enrollment: @other_enrollment,
      content: "这是一个很棒的打卡内容，值得鼓励和支持！我们一起加油吧！"
    )

    suggestions = FlowerIncentiveService.get_smart_giving_suggestions(@user, @event)

    assert suggestions.is_a?(Hash), "应该返回哈希"
    assert suggestions.key?(:suggestions), "应该包含建议列表"
    assert suggestions.key?(:remaining_quota), "应该包含剩余配额"
    assert_equal 3, suggestions[:remaining_quota], "初始配额应该为3"
  end

  # ============================================================================
  # 集成测试
  # ============================================================================

  test "complete flower giving workflow should work end-to-end" do
    # 1. 检查配额
    assert FlowerIncentiveService.can_give_flower?(@user, @event)

    # 2. 获取配额信息
    quota_info = FlowerIncentiveService.get_user_daily_quota_info(@user, @event)
    assert_equal 0, quota_info[:used_flowers]

    # 3. 赠送小红花
    result = FlowerIncentiveService.give_flower_with_confirmation(
      @user, @other_user, @check_in,
      confirmed: true, comment: "完整流程测试"
    )
    assert result[:success]

    # 4. 验证配额更新
    updated_quota = FlowerIncentiveService.get_user_daily_quota_info(@user, @event)
    assert_equal 1, updated_quota[:used_flowers]
    assert_equal 2, updated_quota[:remaining_flowers]

    # 5. 验证小红花记录
    flower = result[:flower]
    assert_equal 1, Flower.where(giver: @user, recipient: @other_user).count

    # 6. 验证接收者统计更新
    @other_enrollment.reload
    assert_equal 1, @other_enrollment.flowers_received_count
  end

  test "service delegation should work correctly" do
    # 验证服务正确委托
    assert_equal FlowerQuotaService.can_give_flower?(@user, @event),
                 FlowerIncentiveService.can_give_flower?(@user, @event)

    # 验证方法签名一致
    quota_info_1 = FlowerQuotaService.get_user_daily_quota_info(@user, @event)
    quota_info_2 = FlowerIncentiveService.get_user_daily_quota_info(@user, @event)

    assert_equal quota_info_1.keys.sort, quota_info_2.keys.sort
    assert_equal quota_info_1[:user_id], quota_info_2[:user_id]
  end
end