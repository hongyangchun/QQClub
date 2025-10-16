class Api::DailyLeadingsController < ApplicationController
  include Authenticable

  skip_before_action :authenticate_user!, only: [:show]

  # POST /api/reading_schedules/:reading_schedule_id/daily_leading
  def create
    reading_schedule = ReadingSchedule.find(params[:reading_schedule_id])
    event = reading_schedule.reading_event

    # 检查活动是否进行中
    unless event.in_progress?
      return render json: { error: "活动未开始或已结束" }, status: :unprocessable_entity
    end

    # 检查是否有权限发布领读内容（前一天权限 + 小组长补位）
    unless event.can_publish_leading_content?(current_user, reading_schedule)
      return render json: {
        error: "只有领读人或小组长可以发布领读内容",
        details: {
          leader_permission: "领读人可提前一天或当天发布",
          group_leader_permission: "小组长全程具备发布权限（补位机制）",
          current_user_role: event.current_leader?(current_user) ? "小组长" : "普通用户",
          is_schedule_leader: reading_schedule.daily_leader_id == current_user.id
        }
      }, status: :forbidden
    end

    daily_leading = reading_schedule.build_daily_leading(daily_leading_params)
    daily_leading.leader = current_user

    if daily_leading.save
      render json: {
        id: daily_leading.id,
        leader: {
          id: daily_leading.leader.id,
          nickname: daily_leading.leader.nickname,
          avatar_url: daily_leading.leader.avatar_url
        },
        reading_suggestion: daily_leading.reading_suggestion,
        questions: daily_leading.questions,
        schedule_date: reading_schedule.date,
        publish_window: "可提前一天或当天发布",
        created_at: daily_leading.created_at
      }, status: :created
    else
      render json: { error: daily_leading.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/reading_schedules/:reading_schedule_id/daily_leading
  def show
    reading_schedule = ReadingSchedule.find(params[:reading_schedule_id])
    daily_leading = reading_schedule.daily_leading

    if daily_leading
      render json: {
        id: daily_leading.id,
        leader: {
          id: daily_leading.leader.id,
          nickname: daily_leading.leader.nickname,
          avatar_url: daily_leading.leader.avatar_url
        },
        reading_suggestion: daily_leading.reading_suggestion,
        questions: daily_leading.questions,
        created_at: daily_leading.created_at
      }
    else
      render json: { error: "今日暂无领读内容" }, status: :not_found
    end
  end

  # PUT /api/reading_schedules/:reading_schedule_id/daily_leading
  def update
    reading_schedule = ReadingSchedule.find(params[:reading_schedule_id])
    daily_leading = reading_schedule.daily_leading
    event = reading_schedule.reading_event

    unless daily_leading
      return render json: { error: "领读内容不存在" }, status: :not_found
    end

    # 检查活动是否进行中
    unless event.in_progress?
      return render json: { error: "活动未开始或已结束" }, status: :unprocessable_entity
    end

    # 检查权限：原作者或当前有效的小组长
    is_original_author = daily_leading.leader_id == current_user.id
    is_current_leader = event.current_leader?(current_user)
    is_today_leader = event.current_daily_leader?(current_user, reading_schedule)

    unless is_original_author || is_current_leader || is_today_leader
      return render json: { error: "无权限修改该内容" }, status: :forbidden
    end

    # 如果当天已经有打卡，不建议修改领读内容
    if reading_schedule.check_ins.any?
      return render json: { error: "已有用户打卡，不建议修改领读内容" }, status: :unprocessable_entity
    end

    if daily_leading.update(daily_leading_params)
      render json: {
        id: daily_leading.id,
        leader: {
          id: daily_leading.leader.id,
          nickname: daily_leading.leader.nickname,
          avatar_url: daily_leading.leader.avatar_url
        },
        reading_suggestion: daily_leading.reading_suggestion,
        questions: daily_leading.questions,
        updated_at: daily_leading.updated_at
      }
    else
      render json: { error: daily_leading.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def daily_leading_params
    params.require(:daily_leading).permit(:reading_suggestion, :questions)
  end
end
