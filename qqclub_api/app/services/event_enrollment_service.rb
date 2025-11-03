# frozen_string_literal: true

# EventEnrollmentService - 活动报名管理服务
# 负责活动报名、验证、人数限制等业务逻辑
class EventEnrollmentService < ApplicationService
  attr_reader :event, :user, :enrollment

  def initialize(event:, user:)
    super()
    @event = event
    @user = user
    @enrollment = nil
  end

  # 主要调用方法
  def call
    handle_errors do
      # 检查活动是否已审批
      unless event.approved?
        return failure!("活动尚未审批通过，无法报名")
      end

      # 检查是否已报名
      if user.event_enrollments.exists?(reading_event: event)
        return failure!("您已经报名该活动")
      end

      # 检查人数限制
      if event.event_enrollments.count >= event.max_participants
        return failure!("活动已满员")
      end

      # 检查活动状态
      unless event.enrolling?
        return failure!("当前活动不在报名期间")
      end

      # 创建报名记录
      create_enrollment
    end

    self
  end

  # 类方法：快速报名
  def self.enroll_user!(event, user)
    new(event: event, user: user).call
  end

  private

  # 创建报名记录
  def create_enrollment
    @enrollment = user.event_enrollments.create!(
      reading_event: event,
      fee_paid_amount: event.enrollment_fee,
      enrollment_date: Time.current
    )

    # 如果是随机分配模式且有足够参与者，自动分配领读人
    if event.leader_assignment_type == 'random' && event.event_enrollments.count >= 3
      event.assign_daily_leaders!
    end

    success!({
      message: "报名成功",
      enrollment_data: {
        id: @enrollment.id,
        user_id: @enrollment.user_id,
        reading_event_id: @enrollment.reading_event_id,
        payment_status: @enrollment.refund_status,
        role: @enrollment.enrollment_type,
        paid_amount: @enrollment.fee_paid_amount,
        created_at: @enrollment.created_at
      }
    })
  end
end