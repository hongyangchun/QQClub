class DailyLeading < ApplicationRecord
  # 关联
  belongs_to :reading_schedule
  belongs_to :leader, class_name: "User"

  # 验证
  validates :reading_suggestion, presence: true
  validates :questions, presence: true
  validates :reading_schedule_id, uniqueness: { message: "今日已有领读内容" }

  # API序列化方法 - 标准化API响应格式
  def as_json_for_api(options = {})
    current_user = options[:current_user]

    result = {
      id: id,
      reading_suggestion: reading_suggestion,
      questions: questions,
      summary: summary,
      created_at: created_at,
      updated_at: updated_at,
      leader: leader.as_json_for_api
    }

    # 添加阅读计划信息
    if options[:include_schedule] && reading_schedule
      result[:reading_schedule] = {
        id: reading_schedule.id,
        day_number: reading_schedule.day_number,
        date: reading_schedule.date,
        reading_progress: reading_schedule.reading_progress
      }
    end

    # 添加活动信息
    if options[:include_event] && reading_schedule&.reading_event
      result[:reading_event] = {
        id: reading_schedule.reading_event.id,
        title: reading_schedule.reading_event.title
      }
    end

    # 添加当前用户的权限信息
    if current_user
      result[:interactions] = {
        can_edit: can_edit?(current_user),
        is_leader: leader_id == current_user.id
      }
    end

    result
  end

  private

  # 权限检查方法
  def can_edit?(current_user)
    return false unless current_user
    return true if current_user.any_admin?  # 管理员可以编辑任何领读内容
    return true if leader_id == current_user.id  # 领读人可以编辑自己的内容
    false
  end
end
