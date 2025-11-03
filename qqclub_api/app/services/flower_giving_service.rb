# 小红花赠送服务
# 负责处理小红花赠送流程，包括配额检查和确认机制
class FlowerGivingService
  class << self
    # 尝试赠送小红花（带每日配额检查和确认提示）
    def give_flower_with_confirmation(giver, recipient, check_in, amount: 1, comment: nil,
                                    flower_type: 'regular', is_anonymous: false, confirmed: false)
      # 获取活动和日期
      event = check_in.reading_event rescue nil
      return { success: false, error: '无法确定活动' } unless event

      date = Date.current

      # 检查是否是活动日
      unless FlowerQuotaService.activity_day?(event, date)
        return { success: false, error: '今日不是活动日，无法赠送小红花' }
      end

      # 检查是否给自己赠送
      if giver.id == recipient.id
        return { success: false, error: '不能给自己赠送小红花' }
      end

      # 获取每日配额
      quota = FlowerQuotaService.get_daily_quota(giver, event, date)

      # 检查配额
      unless quota.can_give_flower?(amount)
        return {
          success: false,
          error: '今日小红花配额已用完',
          remaining: quota.remaining_flowers,
          max: quota.max_flowers,
          used: quota.used_flowers
        }
      end

      # 如果未确认，返回确认信息
      unless confirmed
        return {
          success: true,
          require_confirmation: true,
          confirmation_data: {
            giver: giver.as_json_for_api,
            recipient: recipient.as_json_for_api,
            check_in: {
              id: check_in.id,
              content: check_in.content.truncate(100),
              user: check_in.user.as_json_for_api
            },
            amount: amount,
            comment: comment,
            flower_type: flower_type,
            is_anonymous: is_anonymous,
            date: date,
            quota_info: {
              used: quota.used_flowers,
              max: quota.max_flowers,
              remaining: quota.remaining_flowers
            },
            warning: '赠送成功后无法撤回，请谨慎确认！'
          }
        }
      end

      # 使用事务确保数据一致性
      ActiveRecord::Base.transaction do
        # 扣减配额
        unless FlowerQuotaService.use_quota!(giver, event, amount, date)
          raise '配额使用失败'
        end

        # 创建小红花记录
        flower = Flower.create!(
          giver: giver,
          recipient: recipient,
          check_in: check_in,
          amount: amount,
          flower_type: flower_type,
          comment: comment,
          is_anonymous: is_anonymous
        )

        # 更新配额的最后赠送时间和今日赠送次数
        FlowerQuotaService.record_quota_usage(quota, amount)

        # 更新接收者的统计
        update_recipient_statistics(recipient, flower)

        # 发布小红花赠送事件，解耦通知服务
        DomainEventsService.publish('flower.given', {
          giver: giver,
          recipient: recipient,
          flower: flower,
          check_in: check_in,
          amount: amount,
          comment: comment
        })

        {
          success: true,
          flower: flower,
          remaining_quota: quota.remaining_flowers,
          used_today: quota.used_flowers,
          message: '小红花赠送成功！此操作无法撤回。'
        }
      end
    rescue => e
      Rails.logger.error "小红花赠送失败: #{e.message}"
      {
        success: false,
        error: '小红花赠送失败，请重试',
        details: e.message
      }
    end

    # 简化的赠送方法（不要求确认）
    def give_flower_simple(giver, recipient, check_in, amount: 1, comment: nil,
                           flower_type: 'regular', is_anonymous: false)
      give_flower_with_confirmation(
        giver, recipient, check_in,
        amount: amount, comment: comment,
        flower_type: flower_type, is_anonymous: is_anonymous,
        confirmed: true
      )
    end

    # 批量赠送小红花（管理员功能）
    def batch_give_flowers(admin_user, flower_data_list)
      results = []

      ActiveRecord::Base.transaction do
        flower_data_list.each do |flower_data|
          result = give_flower_with_confirmation(
            flower_data[:giver],
            flower_data[:recipient],
            flower_data[:check_in],
            amount: flower_data[:amount] || 1,
            comment: flower_data[:comment],
            flower_type: flower_data[:flower_type] || 'regular',
            is_anonymous: flower_data[:is_anonymous] || false,
            confirmed: true
          )
          results << result
        end
      end

      {
        success: true,
        total_processed: results.length,
        successful: results.count { |r| r[:success] },
        failed: results.count { |r| !r[:success] },
        details: results
      }
    rescue => e
      Rails.logger.error "批量赠送小红花失败: #{e.message}"
      {
        success: false,
        error: '批量赠送失败',
        details: e.message
      }
    end

    private

    # 发送小红花通知已移至事件订阅者中处理
    # 这样可以解耦FlowerGivingService和NotificationService的依赖关系

  # 更新接收者的统计信息
    def update_recipient_statistics(recipient, flower)
      enrollment = recipient.event_enrollments
                     .where(reading_event_id: flower.check_in.reading_event_id)
                     .first

      if enrollment
        enrollment.increment!(:flowers_received_count)
        enrollment.increment!(:total_flowers_received, flower.amount)
      end
    end
  end
end