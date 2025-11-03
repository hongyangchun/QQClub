# 小红花激励服务 (重构后 - 适配器模式)
# 作为统一入口，委托给专门的服务类处理具体业务逻辑
# 保持向后兼容性，现有代码无需修改
class FlowerIncentiveService
  class << self
    # ============================================================================
    # 配额管理相关方法 - 委托给 FlowerQuotaService
    # ============================================================================

    # 检查用户是否可以在活动中赠送小红花（每日配额）
    def can_give_flower?(user, event, amount = 1, date = Date.current)
      FlowerQuotaService.can_give_flower?(user, event, amount, date)
    end

    # 获取用户在活动中的每日配额信息
    def get_user_daily_quota_info(user, event, date = Date.current)
      FlowerQuotaService.get_user_daily_quota_info(user, event, date)
    end

    # 获取用户在活动中的配额历史
    def get_user_quota_history(user, event, days: 7)
      FlowerQuotaService.get_user_quota_history(user, event, days: days)
    end

    # 活动开始时初始化所有参与者的每日配额
    def initialize_event_daily_quotas(event, max_flowers: 3, days: nil)
      FlowerQuotaService.initialize_event_daily_quotas(event, max_flowers: max_flowers, days: days)
    end

    # 获取活动的每日配额统计
    def get_event_daily_quota_stats(event, date = Date.current)
      FlowerQuotaService.get_event_daily_quota_stats(event, date)
    end

    # 检查配额是否即将用完（提醒功能）
    def check_daily_quota_warning(user, event, date = Date.current, threshold: 0.8)
      FlowerQuotaService.check_daily_quota_warning(user, event, date, threshold: threshold)
    end

    # 使用配额（扣减数量）
    def use_quota!(user, event, amount, date = Date.current)
      FlowerQuotaService.use_quota!(user, event, amount, date)
    end

    # ============================================================================
    # 小红花赠送相关方法 - 委托给 FlowerGivingService
    # ============================================================================

    # 尝试赠送小红花（带每日配额检查和确认提示）
    def give_flower_with_confirmation(giver, recipient, check_in, amount: 1, comment: nil,
                                    flower_type: 'regular', is_anonymous: false, confirmed: false)
      FlowerGivingService.give_flower_with_confirmation(
        giver, recipient, check_in,
        amount: amount, comment: comment,
        flower_type: flower_type, is_anonymous: is_anonymous,
        confirmed: confirmed
      )
    end

    # 简化的赠送方法（不要求确认）
    def give_flower_simple(giver, recipient, check_in, amount: 1, comment: nil,
                         flower_type: 'regular', is_anonymous: false)
      FlowerGivingService.give_flower_simple(
        giver, recipient, check_in,
        amount: amount, comment: comment,
        flower_type: flower_type, is_anonymous: is_anonymous
      )
    end

    # 批量赠送小红花（管理员功能）
    def batch_give_flowers(admin_user, flower_data_list)
      FlowerGivingService.batch_give_flowers(admin_user, flower_data_list)
    end

    # ============================================================================
    # 证书相关方法 - 委托给 FlowerCertificateService
    # ============================================================================

    # 活动结束时生成小红花证书
    def finalize_event_flower_certificates(event)
      FlowerCertificateService.finalize_event_flower_certificates(event)
    end

    # 获取活动的前三名排行榜
    def get_event_top_three(event)
      FlowerCertificateService.get_event_top_three(event)
    end

    # 获取用户的所有小红花证书
    def get_user_certificates(user)
      FlowerCertificateService.get_user_certificates(user)
    end

    # 验证证书有效性
    def validate_certificate(certificate_id)
      FlowerCertificateService.validate_certificate(certificate_id)
    end

    # 重新生成证书（用于修正错误）
    def regenerate_certificate(certificate_id, admin_user)
      FlowerCertificateService.regenerate_certificate(certificate_id, admin_user)
    end

    # 批量生成参与证书
    def batch_generate_participation_certificates(event, user_ids = nil)
      FlowerCertificateService.batch_generate_participation_certificates(event, user_ids)
    end

    # ============================================================================
    # 向后兼容性方法 - 保持原有接口不变
    # ============================================================================

    # 旧版本方法名兼容
    def can_give_flower_legacy?(user, event, amount = 1)
      can_give_flower?(user, event, amount, Date.current)
    end

    def give_flower_with_quota_legacy(giver, recipient, check_in, amount: 1, comment: nil, flower_type: 'regular', is_anonymous: false)
      give_flower_with_confirmation(giver, recipient, check_in,
                                   amount: amount, comment: comment,
                                   flower_type: flower_type, is_anonymous: is_anonymous,
                                   confirmed: false)
    end

    def get_user_quota_info_legacy(user, event)
      get_user_daily_quota_info(user, event, Date.current)
    end

    def initialize_event_flower_quotas_legacy(event, max_flowers: 3)
      initialize_event_daily_quotas(event, max_flowers: max_flowers)
    end

    # 别名方法，确保现有代码继续工作
    alias_method :can_give_flower_old, :can_give_flower_legacy?
    alias_method :give_flower_with_quota_old, :give_flower_with_quota_legacy
    alias_method :get_user_quota_info_old, :get_user_quota_info_legacy
    alias_method :initialize_event_flower_quotas_old, :initialize_event_flower_quotas_legacy

    # ============================================================================
    # 便捷方法和组合操作
    # ============================================================================

    # 一键检查用户在活动中的完整状态
    def get_user_complete_status(user, event, date = Date.current)
      {
        quota_info: get_user_daily_quota_info(user, event, date),
        can_give_flower: can_give_flower?(user, event, 1, date),
        quota_warning: check_daily_quota_warning(user, event, date, threshold: 0.8),
        certificates: get_user_certificates(user)
      }
    end

    # 获取活动完整统计信息
    def get_event_complete_stats(event, date = Date.current)
      {
        quota_stats: get_event_daily_quota_stats(event, date),
        top_three: event.completed? ? get_event_top_three(event) : nil,
        event_status: {
          status: event.status,
          participants_count: event.participants.count,
          is_completed: event.completed?
        }
      }
    end

    # 智能赠送建议（基于配额和历史数据）
    def get_smart_giving_suggestions(giver, event, limit = 5)
      quota_info = get_user_daily_quota_info(giver, event)
      return { suggestions: [], message: '今日配额已用完' } unless quota_info[:can_give_more]

      # 获取今日可赠送的打卡列表
      available_check_ins = CheckIn.joins(:reading_schedule, :user)
                                 .where(reading_schedules: { reading_event: event, date: Date.current })
                                 .where.not(user: giver)
                                 .includes(:user)
                                 .limit(limit)

      suggestions = available_check_ins.map do |check_in|
        {
          check_in: check_in.as_json_for_api(include_user: true),
          recommended_flower_type: 'regular',
          reason: '今日打卡，值得鼓励'
        }
      end

      {
        suggestions: suggestions,
        remaining_quota: quota_info[:remaining_flowers],
        message: "发现 #{suggestions.count} 个可赠送的打卡"
      }
    end
  end
end