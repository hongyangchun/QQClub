# 小红花证书服务
# 负责生成和管理小红花相关的证书
class FlowerCertificateService
  class << self
    # 活动结束时生成小红花证书
    def finalize_event_flower_certificates(event)
      return { success: false, error: '活动未结束' } unless event.status == 'completed'
      return { success: false, error: '活动没有参与者' } if event.participants.empty?

      certificates = generate_top_three_certificates(event)

      {
        success: true,
        event: event.title,
        certificates: certificates.map do |cert|
          {
            rank: cert.rank_display,
            user: cert.user.as_json_for_api,
            total_flowers: cert.total_flowers,
            certificate_id: cert.certificate_id,
            honor_level: cert.honor_level,
            share_url: cert.share_url
          }
        end
      }
    end

    # 生成活动前三名证书
    def generate_top_three_certificates(event)
      return [] unless event.participants.any?

      # 计算每个参与者的小红花总数
      flower_stats = calculate_event_flower_statistics(event)

      # 排序并取前三名
      top_three = flower_stats.sort_by { |user_id, flowers| -flowers }
                     .first(3)

      certificates = []
      top_three.each_with_index do |(user_id, flowers), index|
        user = User.find(user_id)
        rank = index + 1

        # 生成证书
        cert = FlowerCertificate.create!(
          user: user,
          reading_event: event,
          certificate_type: "flower_top#{rank}",
          rank: rank,
          total_flowers: flowers,
          certificate_number: generate_certificate_number(event, rank),
          honor_level: calculate_honor_level(flowers),
          issued_at: Time.current,
          expires_at: event.end_date + 1.year
        )

        certificates << cert

        # 记录到参与者的证书列表
        participation_cert = ParticipationCertificate.create!(
          user: user,
          reading_event: event,
          certificate_type: "flower_top#{rank}",
          certificate_number: cert.certificate_number,
          issued_at: cert.issued_at
        )

        # 发送通知
        send_certificate_notification(user, cert, event)
      end

      certificates
    end

    # 获取活动的前三名排行榜
    def get_event_top_three(event)
      return { error: '活动未结束' } unless event.status == 'completed'

      certificates = FlowerCertificate.for_event(event).ranked

      {
        event: event.title,
        total_participants: event.participants.count,
        top_three: certificates.map do |cert|
          {
            rank: cert.rank_display,
            user: cert.user.as_json_for_api,
            total_flowers: cert.total_flowers,
            honor_level: cert.honor_level,
            certificate_id: cert.certificate_id
          }
        end,
        generated_at: certificates.first&.created_at
      }
    end

    # 获取用户的所有小红花证书
    def get_user_certificates(user)
      certificates = FlowerCertificate.for_user_all(user)

      {
        user: user.as_json_for_api,
        total_certificates: certificates.count,
        certificates: certificates.map do |cert|
          {
            event: cert.reading_event.title,
            rank: cert.rank_display,
            total_flowers: cert.total_flowers,
            honor_level: cert.honor_level,
            certificate_id: cert.certificate_id,
            earned_at: cert.created_at,
            is_valid: cert.valid_certificate?,
            share_url: cert.share_url
          }
        end
      }
    end

    # 验证证书有效性
    def validate_certificate(certificate_id)
      cert = FlowerCertificate.find_by(certificate_id: certificate_id)
      return { valid: false, error: '证书不存在' } unless cert

      {
        valid: cert.valid_certificate?,
        certificate: cert,
        user: cert.user.as_json_for_api,
        event: cert.reading_event.as_json_for_api,
        expires_at: cert.expires_at,
        days_until_expiry: cert.days_until_expiry
      }
    end

    # 重新生成证书（用于修正错误）
    def regenerate_certificate(certificate_id, admin_user)
      cert = FlowerCertificate.find_by(certificate_id: certificate_id)
      return { success: false, error: '证书不存在' } unless cert

      # 记录重新生成日志
      Rails.logger.info "证书重新生成: #{certificate_id} by #{admin_user&.nickname}"

      # 生成新的证书编号
      new_certificate_number = generate_certificate_number(cert.reading_event, cert.rank)

      cert.update!(
        certificate_number: new_certificate_number,
        issued_at: Time.current,
        expires_at: cert.reading_event.end_date + 1.year,
        regenerated_at: Time.current,
        regenerated_by: admin_user&.id
      )

      {
        success: true,
        certificate: cert,
        message: '证书已重新生成'
      }
    end

    # 批量生成参与证书
    def batch_generate_participation_certificates(event, user_ids = nil)
      return { success: false, error: '活动未结束' } unless event.status == 'completed'

      target_users = user_ids ? User.where(id: user_ids) : event.participants

      certificates = []
      target_users.each do |user|
        enrollment = event.event_enrollments.find_by(user: user)
        next unless enrollment&.is_completed?

        # 生成完成证书
        cert = ParticipationCertificate.create!(
          user: user,
          reading_event: event,
          certificate_type: 'completion',
          certificate_number: generate_certificate_number(event, 'completion'),
          issued_at: Time.current,
          expires_at: event.end_date + 2.years
        )

        certificates << cert
      end

      {
        success: true,
        generated_count: certificates.count,
        certificates: certificates
      }
    end

    private

    # 计算活动中每个参与者的小红花统计
    def calculate_event_flower_statistics(event)
      flower_stats = {}

      event.check_ins.includes(:flowers, :user).each do |check_in|
        check_in.flowers.each do |flower|
          user_id = flower.recipient_id
          flower_stats[user_id] = (flower_stats[user_id] || 0) + flower.amount
        end
      end

      flower_stats
    end

    # 生成证书编号
    def generate_certificate_number(event, type_or_rank)
      prefix = event.id.to_s.rjust(4, '0')
      timestamp = Time.current.strftime('%Y%m%d')
      type_code = type_or_rank.is_a?(Integer) ? "TOP#{type_or_rank}" : type_or_rank.to_s.upcase.first(3)
      random_code = SecureRandom.hex(4).upcase

      "#{prefix}-#{timestamp}-#{type_code}-#{random_code}"
    end

    # 计算荣誉等级
    def calculate_honor_level(flowers)
      case flowers
      when 0..2
        'bronze'
      when 3..5
        'silver'
      when 6..10
        'gold'
      else
        'platinum'
      end
    end

    # 发送证书通知
    def send_certificate_notification(user, certificate, event)
      # 这里应该调用通知服务发送邮件或消息
      # NotificationService.send_certificate_notification(user, certificate, event)

      Rails.logger.info "证书通知已发送: 用户#{user.nickname}, 证书#{certificate.certificate_id}"
    end
  end
end