# frozen_string_literal: true

require "test_helper"

class FlowerServiceDelegationTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user(:user)
    @event = create_test_reading_event(
      title: "测试阅读活动",
      start_date: Date.today,
      end_date: Date.today + 7.days,
      status: 'in_progress'
    )
    @enrollment = EventEnrollment.create!(
      user: @user,
      reading_event: @event,
      enrollment_type: 'participant',
      status: 'enrolled',
      enrollment_date: Time.current
    )
  end

  def teardown
    # 清理测试数据
    Flower.delete_all
    FlowerQuota.delete_all
    EventEnrollment.delete_all
    ReadingEvent.delete_all
    User.delete_all
  end

  # ============================================================================
  # 测试服务委托功能
  # ============================================================================

  test "FlowerIncentiveService should delegate to FlowerQuotaService correctly" do
    # 测试配额检查委托
    assert_nothing_raised do
      result = FlowerIncentiveService.can_give_flower?(@user, @event)
      assert result.is_a?(TrueClass) || result.is_a?(FalseClass)
    end

    # 测试配额信息获取委托
    assert_nothing_raised do
      quota_info = FlowerIncentiveService.get_user_daily_quota_info(@user, @event)
      assert quota_info.is_a?(Hash)
      assert quota_info.key?(:user_id)
      assert quota_info.key?(:event_id)
      assert quota_info.key?(:used_flowers)
      assert quota_info.key?(:max_flowers)
      assert quota_info.key?(:remaining_flowers)
    end
  end

  test "FlowerIncentiveService should delegate to FlowerGivingService correctly" do
    # 测试方法委托（不涉及复杂的数据操作）
    assert_nothing_raised do
      # 验证方法存在且可以调用
      assert FlowerIncentiveService.respond_to?(:give_flower_with_confirmation)
      assert FlowerIncentiveService.respond_to?(:give_flower_simple)
      assert FlowerIncentiveService.respond_to?(:batch_give_flowers)
    end

    # 测试错误处理委托
    assert_nothing_raised do
      # 传递nil参数应该能正确处理
      result = FlowerIncentiveService.give_flower_with_confirmation(
        nil, nil, nil,
        confirmed: true,
        comment: "测试错误处理"
      )
      assert result.is_a?(Hash)
      assert result.key?(:success)
      assert_not result[:success]
    end
  end

  test "FlowerIncentiveService should delegate to FlowerCertificateService correctly" do
    # 测试证书验证委托
    assert_nothing_raised do
      result = FlowerIncentiveService.validate_certificate("INVALID-CERT-ID")
      assert result.is_a?(Hash)
      assert result.key?(:valid)
      assert_not result[:valid]
    end
  end

  # ============================================================================
  # 测试向后兼容性
  # ============================================================================

  test "should maintain backward compatibility with legacy methods" do
    # 测试旧方法名是否仍然工作
    assert_nothing_raised do
      # 测试所有旧方法名都能正常调用
      FlowerIncentiveService.can_give_flower_legacy?(@user, @event)
      FlowerIncentiveService.get_user_quota_info_legacy(@user, @event)
      FlowerIncentiveService.initialize_event_flower_quotas_legacy(@event)

      # 测试别名方法
      FlowerIncentiveService.can_give_flower_old(@user, @event)
      FlowerIncentiveService.get_user_quota_info_old(@user, @event)
      FlowerIncentiveService.initialize_event_flower_quotas_old(@event)
    end
  end

  test "should provide new convenience methods" do
    # 测试新的便捷方法
    assert_nothing_raised do
      complete_status = FlowerIncentiveService.get_user_complete_status(@user, @event)
      assert complete_status.is_a?(Hash)
      assert complete_status.key?(:quota_info)
      assert complete_status.key?(:can_give_flower)
      assert complete_status.key?(:quota_warning)
      assert complete_status.key?(:certificates)
    end

    assert_nothing_raised do
      event_stats = FlowerIncentiveService.get_event_complete_stats(@event)
      assert event_stats.is_a?(Hash)
      assert event_stats.key?(:quota_stats)
      assert event_stats.key?(:top_three)
      assert event_stats.key?(:event_status)
    end
  end

  # ============================================================================
  # 测试服务方法签名一致性
  # ============================================================================

  test "service methods should have consistent signatures" do
    # 测试配额检查方法签名一致
    original_result = FlowerQuotaService.can_give_flower?(@user, @event, 1, Date.current)
    delegated_result = FlowerIncentiveService.can_give_flower?(@user, @event, 1, Date.current)
    assert_equal original_result, delegated_result

    # 测试配额信息方法签名一致
    original_quota = FlowerQuotaService.get_user_daily_quota_info(@user, @event, Date.current)
    delegated_quota = FlowerIncentiveService.get_user_daily_quota_info(@user, @event, Date.current)

    # 验证返回结构相同
    assert_equal original_quota.keys.sort, delegated_quota.keys.sort
    assert_equal original_quota[:user_id], delegated_quota[:user_id]
    assert_equal original_quota[:event_id], delegated_quota[:event_id]
  end

  # ============================================================================
  # 测试错误处理
  # ============================================================================

  test "should handle invalid parameters gracefully" do
    # 测试空参数
    assert_nothing_raised do
      result = FlowerIncentiveService.can_give_flower?(nil, @event)
      assert_equal false, result
    end

    assert_nothing_raised do
      result = FlowerIncentiveService.get_user_daily_quota_info(nil, @event)
      assert result.is_a?(Hash)
      assert result.key?(:error)
    end

    assert_nothing_raised do
      result = FlowerIncentiveService.validate_certificate(nil)
      assert result.is_a?(Hash)
      assert_equal false, result[:valid]
      assert_equal "证书不存在", result[:error]
    end
  end

  # ============================================================================
  # 测试配额初始化
  # ============================================================================

  test "should initialize event quotas correctly" do
    # 测试配额初始化
    assert_nothing_raised do
      result = FlowerIncentiveService.initialize_event_daily_quotas(@event, max_flowers: 5)
      assert_equal true, result
    end

    # 验证配额记录已创建
    quota = FlowerQuota.find_by(user: @user, reading_event: @event, quota_date: Date.current)
    assert_not_nil quota
    assert_equal 5, quota.max_flowers
    assert_equal 0, quota.used_flowers
  end
end