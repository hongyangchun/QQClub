# 社交分享服务
# 支持生成分享到微信的图片、链接和文案
class SocialShareService
  class << self
    # 为每日排行榜生成分享内容
    def generate_daily_leaderboard_share(event, date = Date.yesterday)
      stat = DailyFlowerStat.find_by(reading_event: event, stats_date: date)
      return { success: false, error: '统计数据不存在' } unless stat

      # 生成分享文案
      share_text = stat.share_text_for_wechat

      # 生成分享图片URL
      share_image_url = stat.share_image_url || stat.generate_share_image_url

      # 生成分享链接
      share_url = generate_share_url('daily_leaderboard', {
        event_id: event.id,
        date: date.strftime('%Y-%m-%d')
      })

      # 生成小程序码URL（如果需要）
      miniprogram_qrcode_url = generate_miniprogram_qrcode('pages/flower/daily_leaderboard', {
        event_id: event.id,
        date: date.strftime('%Y-%m-%d')
      })

      {
        success: true,
        share_type: 'daily_leaderboard',
        content: {
          title: "#{event.title} - #{date.strftime('%m月%d日')}小红花排行榜",
          text: share_text,
          image_url: share_image_url,
          share_url: share_url,
          miniprogram_qrcode_url: miniprogram_qrcode_url,
          platform_specific: {
            wechat: {
              title: "#{event.title}小红花榜",
              desc: "看看今天谁获得的小红花最多！",
              image_url: share_image_url,
              link: share_url,
              miniprogram: {
                appid: ENV['WECHAT_MINIPROGRAM_APPID'],
                path: "pages/flower/daily_leaderboard?event_id=#{event.id}&date=#{date.strftime('%Y-%m-%d')}",
                image_url: miniprogram_qrcode_url
              }
            },
            weibo: {
              title: "我在#{event.title}活动中获得#{stat.top_three.first&.dig(:total_flowers) || 0}朵小红花！",
              text: share_text,
              image_url: share_image_url,
              hashtags: ['#读书打卡', '#小红花', '#共读成长']
            }
          }
        },
        metadata: {
          event_id: event.id,
          event_title: event.title,
          date: date,
          generated_at: Time.current,
          share_count: stat.share_count
        }
      }
    end

    # 为最终排行榜生成分享内容
    def generate_final_leaderboard_share(event)
      return { success: false, error: '活动未结束' } unless event.status == 'completed'

      # 获取最终排行榜
      certificates = FlowerCertificate.for_event(event).ranked
      return { success: false, error: '无获奖者数据' } if certificates.empty?

      # 生成分享文案
      share_text = generate_final_leaderboard_text(event, certificates)

      # 生成分享图片URL
      share_image_url = generate_final_leaderboard_image_url(event)

      # 生成分享链接
      share_url = generate_share_url('final_leaderboard', {
        event_id: event.id
      })

      # 生成小程序码URL
      miniprogram_qrcode_url = generate_miniprogram_qrcode('pages/flower/final_leaderboard', {
        event_id: event.id
      })

      {
        success: true,
        share_type: 'final_leaderboard',
        content: {
          title: "#{event.title} - 最终小红花排行榜",
          text: share_text,
          image_url: share_image_url,
          share_url: share_url,
          miniprogram_qrcode_url: miniprogram_qrcode_url,
          platform_specific: {
            wechat: {
              title: "#{event.title}小红花总榜出炉！",
              desc: "来看看谁是最优秀的阅读者！",
              image_url: share_image_url,
              link: share_url,
              miniprogram: {
                appid: ENV['WECHAT_MINIPROGRAM_APPID'],
                path: "pages/flower/final_leaderboard?event_id=#{event.id}",
                image_url: miniprogram_qrcode_url
              }
            },
            weibo: {
              title: "恭喜#{event.title}小红花TOP3诞生！",
              text: share_text,
              image_url: share_image_url,
              hashtags: ['#读书打卡', '#小红花', '#共读成长', '#阅读达人']
            }
          }
        },
        metadata: {
          event_id: event.id,
          event_title: event.title,
          certificates_count: certificates.count,
          generated_at: Time.current
        }
      }
    end

    # 为用户证书生成分享内容
    def generate_certificate_share(certificate)
      return { success: false, error: '证书不存在' } unless certificate

      user = certificate.user
      event = certificate.reading_event

      # 生成分享文案
      share_text = generate_certificate_text(user, event, certificate)

      # 生成分享图片URL
      share_image_url = certificate.certificate_image_path

      # 生成分享链接
      share_url = generate_share_url('certificate', {
        certificate_id: certificate.certificate_id
      })

      # 生成小程序码URL
      miniprogram_qrcode_url = generate_miniprogram_qrcode('pages/flower/certificate', {
        certificate_id: certificate.certificate_id
      })

      {
        success: true,
        share_type: 'certificate',
        content: {
          title: "#{user.nickname}的#{certificate.honor_level}证书",
          text: share_text,
          image_url: share_image_url,
          share_url: share_url,
          miniprogram_qrcode_url: miniprogram_qrcode_url,
          platform_specific: {
            wechat: {
              title: "我获得了#{certificate.honor_level}证书！",
              desc: "在#{event.title}活动中表现出色",
              image_url: share_image_url,
              link: share_url,
              miniprogram: {
                appid: ENV['WECHAT_MINIPROGRAM_APPID'],
                path: "pages/flower/certificate?certificate_id=#{certificate.certificate_id}",
                image_url: miniprogram_qrcode_url
              }
            },
            weibo: {
              title: "获得#{certificate.honor_level}证书！",
              text: share_text,
              image_url: share_image_url,
              hashtags: ['#读书打卡', '#小红花', '#共读成长', '#荣誉证书']
            }
          }
        },
        metadata: {
          certificate_id: certificate.certificate_id,
          user_id: user.id,
          event_id: event.id,
          rank: certificate.rank,
          generated_at: Time.current
        }
      }
    end

    # 为用户个人成就生成分享内容
    def generate_user_achievement_share(user, event, stats = {})
      return { success: false, error: '用户或活动不存在' } unless user && event

      # 获取用户在活动中的小红花统计
      flowers_received = stats[:flowers_received] || Flower.joins(:recipient)
                                                              .joins(check_in: :event_enrollment)
                                                              .where(event_enrollments: { reading_event_id: event.id, user: user })
                                                              .sum(:amount)

      flowers_given = stats[:flowers_given] || Flower.joins(:giver)
                                                           .joins(check_in: :event_enrollment)
                                                           .where(event_enrollments: { reading_event_id: event.id, user: user })
                                                           .sum(:amount)

      # 获取用户排名
      rank = get_user_flower_rank(user, event)

      # 生成分享文案
      share_text = generate_user_achievement_text(user, event, {
        flowers_received: flowers_received,
        flowers_given: flowers_given,
        rank: rank
      })

      # 生成分享图片URL
      share_image_url = generate_user_achievement_image_url(user, event, {
        flowers_received: flowers_received,
        flowers_given: flowers_given,
        rank: rank
      })

      # 生成分享链接
      share_url = generate_share_url('user_achievement', {
        user_id: user.id,
        event_id: event.id
      })

      {
        success: true,
        share_type: 'user_achievement',
        content: {
          title: "#{user.nickname}在#{event.title}中的成就",
          text: share_text,
          image_url: share_image_url,
          share_url: share_url,
          platform_specific: {
            wechat: {
              title: "我的#{event.title}阅读成就",
              desc: "共获得#{flowers_received}朵小红花",
              image_url: share_image_url,
              link: share_url,
              miniprogram: {
                appid: ENV['WECHAT_MINIPROGRAM_APPID'],
                path: "pages/flower/user_achievement?user_id=#{user.id}&event_id=#{event.id}",
                image_url: share_image_url
              }
            },
            weibo: {
              title: "分享我的阅读成就",
              text: share_text,
              image_url: share_image_url,
              hashtags: ['#读书打卡', '#小红花', '#共读成长', '#我的成就']
            }
          }
        },
        metadata: {
          user_id: user.id,
          event_id: event.id,
          flowers_received: flowers_received,
          flowers_given: flowers_given,
          rank: rank,
          generated_at: Time.current
        }
      }
    end

    # 记录分享行为
    def record_share_action(share_type, resource_id, platform, user_id = nil)
      ShareAction.create!(
        share_type: share_type,
        resource_id: resource_id,
        platform: platform,
        user_id: user_id,
        ip_address: nil, # 可以从请求中获取
        user_agent: nil,  # 可以从请求中获取
        shared_at: Time.current
      )
    rescue => e
      Rails.logger.error "记录分享行为失败: #{e.message}"
    end

    # 获取分享统计数据
    def get_share_stats(event, days = 7)
      start_date = days.days.ago.to_date

      stats = ShareAction.where(share_type: ['daily_leaderboard', 'final_leaderboard', 'certificate'])
                        .where('created_at >= ?', start_date)
                        .group(:share_type, :platform)
                        .count

      {
        event: event.as_json_for_api,
        period: "#{start_date} 至 #{Date.current}",
        stats: stats,
        total_shares: stats.values.sum,
        platform_breakdown: stats.group_by { |(type, platform), count| platform }
                                        .transform_values(&:sum)
      }
    end

    private

    # 生成最终排行榜文案
    def generate_final_leaderboard_text(event, certificates)
      return '' if certificates.empty?

      text = "🎊 #{event.title} 最终小红花排行榜揭晓！\n\n"
      text += "🏆 优秀小红花获得者：\n"

      certificates.each_with_index do |cert, index|
        emoji = ['🥇', '🥈', '🥉'][index]
        text += "#{emoji} #{cert.user.nickname} - #{cert.total_flowers}朵\n"
        text += "   荣获#{cert.honor_level}证书\n"
      end

      text += "\n💝 感谢所有参与者的坚持与鼓励！"
      text += "\n#读书打卡 #小红花 #共读成长 #阅读达人"

      text
    end

    # 生成证书分享文案
    def generate_certificate_text(user, event, certificate)
      text = "🏆 我在#{event.title}活动中\n"
      text += "获得#{certificate.honor_level}证书！\n\n"
      text += "🌸 共获得#{certificate.total_flowers}朵小红花\n"
      text += "📚 排名第#{certificate.rank}名\n"
      text += "🎉 感谢小伙伴们的鼓励与支持！\n\n"
      text += "#读书打卡 #小红花 #共读成长 #荣誉证书"

      text
    end

    # 生成用户成就文案
    def generate_user_achievement_text(user, event, stats)
      rank_text = stats[:rank] ? "排名第#{stats[:rank]}名" : "继续努力"

      text = "📖 我在#{event.title}中的阅读成就\n\n"
      text += "🌸 获得#{stats[:flowers_received]}朵小红花\n"
      text += "💝 送出#{stats[:flowers_given]}朵小红花\n"
      text += "🏆 #{rank_text}\n"
      text += "💝 感谢大家的鼓励与支持！\n\n"
      text += "#读书打卡 #小红花 #共读成长 #我的成就"

      text
    end

    # 生成分享URL
    def generate_share_url(type, params)
      base_url = Rails.application.config.base_url || 'http://localhost:3000'

      case type
      when 'daily_leaderboard'
        "#{base_url}/share/daily-leaderboard?#{params.to_query}"
      when 'final_leaderboard'
        "#{base_url}/share/final-leaderboard?#{params.to_query}"
      when 'certificate'
        "#{base_url}/share/certificate?#{params.to_query}"
      when 'user_achievement'
        "#{base_url}/share/user-achievement?#{params.to_query}"
      else
        "#{base_url}/share/#{type}?#{params.to_query}"
      end
    end

    # 生成小程序码URL
    def generate_miniprogram_qrcode(path, params = {})
      # 这里可以集成微信小程序API生成小程序码
      # 或者使用第三方服务
      base_url = Rails.application.config.base_url || 'http://localhost:3000'
      query_string = params.to_query
      full_path = query_string.empty? ? path : "#{path}?#{query_string}"

      "#{base_url}/api/miniprogram/qrcode?path=#{CGI.escape(full_path)}"
    end

    # 生成最终排行榜图片URL
    def generate_final_leaderboard_image_url(event)
      timestamp = Time.current.to_i
      base_url = Rails.application.config.base_url || 'http://localhost:3000'
      "#{base_url}/share-images/final-leaderboard/#{event.id}?t=#{timestamp}"
    end

    # 生成用户成就图片URL
    def generate_user_achievement_image_url(user, event, stats)
      timestamp = Time.current.to_i
      base_url = Rails.application.config.base_url || 'http://localhost:3000'
      params = {
        user_id: user.id,
        event_id: event.id,
        flowers_received: stats[:flowers_received],
        flowers_given: stats[:flowers_given],
        rank: stats[:rank]
      }
      "#{base_url}/share-images/user-achievement?#{params.to_query}&t=#{timestamp}"
    end

    # 获取用户在小红花排行榜中的排名
    def get_user_flower_rank(user, event)
      # 计算用户在活动中获得的小红花总数
      user_flowers = Flower.joins(:recipient)
                          .joins(check_in: :event_enrollment)
                          .where(event_enrollments: { reading_event_id: event.id, user: user })
                          .sum(:amount)

      # 计算所有用户的小红花总数并排序
      all_flowers = Flower.joins(:recipient)
                         .joins(check_in: :event_enrollment)
                         .where(event_enrollments: { reading_event_id: event.id })
                         .group(:recipient_id)
                         .sum(:amount)
                         .sort_by { |_, flowers| -flowers }
                         .to_h

      # 找到用户排名
      rank = all_flowers.keys.index(user.id)
      rank ? rank + 1 : nil
    end
  end
end

# 分享行为记录模型（如果需要的话）
class ShareAction < ApplicationRecord
  # 验证
  validates :share_type, :resource_id, :platform, presence: true

  # 作用域
  scope :for_share_type, ->(type) { where(share_type: type) }
  scope :for_platform, ->(platform) { where(platform: platform) }
  scope :recent, -> { order(shared_at: :desc) }
end