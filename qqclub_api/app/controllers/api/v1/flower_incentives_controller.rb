class Api::V1::FlowerIncentivesController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :find_reading_event
  before_action :check_event_participation

  # 获取用户在活动中的配额信息
  def quota_info
    quota_info = FlowerIncentiveService.get_user_quota_info(current_user, @reading_event)

    if quota_info[:error]
      render json: {
        success: false,
        error: quota_info[:error]
      }, status: :unprocessable_entity
    else
      render json: {
        success: true,
        data: quota_info
      }
    end
  end

  # 赠送小红花（带配额检查和确认提示）
  def give_flower
    # 验证参数
    recipient_id = params[:recipient_id]
    check_in_id = params[:check_in_id]
    amount = params[:amount]&.to_i || 1
    comment = params[:comment]
    flower_type = params[:flower_type] || 'regular'
    is_anonymous = params[:is_anonymous] == true

    # 验证必要参数
    unless recipient_id && check_in_id
      return render json: {
        success: false,
        error: '缺少必要参数：recipient_id 和 check_in_id'
      }, status: :bad_request
    end

    # 查找接收者和打卡记录
    recipient = User.find_by(id: recipient_id)
    check_in = CheckIn.find_by(id: check_in_id)

    unless recipient && check_in
      return render json: {
        success: false,
        error: '接收者或打卡记录不存在'
      }, status: :not_found
    end

    # 验证打卡记录是否属于当前活动
    if check_in.reading_schedule&.reading_event_id != @reading_event.id
      return render json: {
        success: false,
        error: '该打卡记录不属于当前活动'
      }, status: :unprocessable_entity
    end

    # 检查是否是给自己赠送
    if recipient.id == current_user.id
      return render json: {
        success: false,
        error: '不能给自己赠送小红花'
      }, status: :unprocessable_entity
    end

    # 检查配额
    unless FlowerIncentiveService.can_give_flower?(current_user, @reading_event, amount)
      return render json: {
        success: false,
        error: '小红花配额不足',
        quota_info: FlowerIncentiveService.get_user_quota_info(current_user, @reading_event)
      }, status: :unprocessable_entity
    end

    # 根据请求类型处理（确认或直接赠送）
    if params[:confirm] == true
      # 用户已确认，执行赠送
      result = FlowerIncentiveService.give_flower_with_quota(
        current_user,
        recipient,
        check_in,
        amount: amount,
        comment: comment,
        flower_type: flower_type,
        is_anonymous: is_anonymous
      )

      if result[:success]
        render json: {
          success: true,
          message: '小红花赠送成功！',
          data: {
            flower: result[:flower].as_json_for_api,
            remaining_quota: result[:remaining_quota],
            warning: '赠送成功后无法撤回，请谨慎操作'
          }
        }
      else
        render json: {
          success: false,
          error: result[:error],
          message: '小红花赠送失败，请重试'
        }, status: :unprocessable_entity
      end
    else
      # 需要用户确认
      quota_info = FlowerIncentiveService.get_user_quota_info(current_user, @reading_event)

      render json: {
        success: true,
        require_confirmation: true,
        message: '即将赠送小红花，此操作不可撤回，请确认',
        data: {
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
          remaining_quota: quota_info[:remaining_flowers],
          warning: '赠送成功后无法撤回，请谨慎确认'
        }
      }
    end
  end

  # 获取活动的前三名排行榜
  def top_three
    if @reading_event.status != 'completed'
      return render json: {
        success: false,
        error: '活动尚未结束，排行榜暂未生成'
      }, status: :unprocessable_entity
    end

    result = FlowerIncentiveService.get_event_top_three(@reading_event)

    if result[:error]
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    else
      render json: {
        success: true,
        data: result
      }
    end
  end

  # 获取用户的证书历史
  def my_certificates
    certificates = FlowerIncentiveService.get_user_certificates(current_user)

    render json: {
      success: true,
      data: certificates
    }
  end

  # 获取证书详情
  def certificate_detail
    certificate_id = params[:certificate_id]

    unless certificate_id
      return render json: {
        success: false,
        error: '缺少证书ID'
      }, status: :bad_request
    end

    certificate = FlowerCertificate.find_by(certificate_id: certificate_id)

    unless certificate
      return render json: {
        success: false,
        error: '证书不存在'
      }, status: :not_found
    end

    # 检查权限（只有证书所有者或活动参与者可以查看）
    if certificate.user_id != current_user.id && !@reading_event.participants.include?(current_user)
      return render json: {
        success: false,
        error: '没有权限查看该证书'
      }, status: :forbidden
    end

    render json: {
      success: true,
      data: {
        certificate: certificate.as_json_for_api,
        event: certificate.reading_event.as_json_for_api,
        user: certificate.user.as_json_for_api,
        share_url: certificate.share_url,
        certificate_image_url: certificate.certificate_image_path
      }
    }
  end

  # 生成活动结束证书（管理员权限）
  def finalize_certificates
    unless current_user.any_admin?
      return render json: {
        success: false,
        error: '没有权限执行此操作'
      }, status: :forbidden
    end

    if @reading_event.status != 'completed'
      return render json: {
        success: false,
        error: '只有已结束的活动才能生成证书'
      }, status: :unprocessable_entity
    end

    result = FlowerIncentiveService.finalize_event_flower_certificates(@reading_event)

    if result[:success]
      render json: {
        success: true,
        message: '活动证书生成成功！',
        data: result
      }
    else
      render json: {
        success: false,
        error: result[:error]
      }, status: :unprocessable_entity
    end
  end

  # 活动开始时初始化配额（管理员权限）
  def initialize_quotas
    unless current_user.any_admin?
      return render json: {
        success: false,
        error: '没有权限执行此操作'
      }, status: :forbidden
    end

    max_flowers = params[:max_flowers]&.to_i || 3

    if FlowerIncentiveService.initialize_event_flower_quotas(@reading_event, max_flowers: max_flowers)
      render json: {
        success: true,
        message: '活动小红花配额初始化成功',
        data: {
          event: @reading_event.as_json_for_api,
          max_flowers: max_flowers,
          participants_count: @reading_event.participants.count
        }
      }
    else
      render json: {
        success: false,
        error: '配额初始化失败，请重试'
      }, status: :unprocessable_entity
    end
  end

  private

  def find_reading_event
    @reading_event = ReadingEvent.find(params[:reading_event_id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: '活动不存在'
    }, status: :not_found
  end

  def check_event_participation
    unless @reading_event.participants.include?(current_user) || current_user.any_admin?
      render json: {
        success: false,
        error: '您尚未参与此活动或没有权限访问'
      }, status: :forbidden
    end
  end
end