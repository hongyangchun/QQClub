class Api::CheckInsController < ApplicationController
  include Authenticable

  # POST /api/reading_schedules/:reading_schedule_id/check_ins
  def create
    reading_schedule = ReadingSchedule.find(params[:reading_schedule_id])
    enrollment = current_user.enrollments.find_by(reading_event: reading_schedule.reading_event)

    unless enrollment
      return render json: { error: "未报名该活动" }, status: :unprocessable_entity
    end

    check_in = CheckIn.new(check_in_params)
    check_in.user = current_user
    check_in.reading_schedule = reading_schedule
    check_in.enrollment = enrollment

    if check_in.save
      render json: check_in, status: :created
    else
      render json: { error: check_in.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/reading_schedules/:reading_schedule_id/check_ins
  def index
    reading_schedule = ReadingSchedule.find(params[:reading_schedule_id])
    check_ins = reading_schedule.check_ins.includes(:user, :flower)

    render json: check_ins.map { |ci|
      {
        id: ci.id,
        user: {
          id: ci.user.id,
          nickname: ci.user.nickname,
          avatar_url: ci.user.avatar_url
        },
        content: ci.content,
        word_count: ci.word_count,
        status: ci.status,
        submitted_at: ci.submitted_at,
        has_flower: ci.has_flower?,
        flower: ci.flower ? {
          giver: {
            id: ci.flower.giver.id,
            nickname: ci.flower.giver.nickname
          },
          comment: ci.flower.comment
        } : nil
      }
    }
  end

  # GET /api/check_ins/:id
  def show
    check_in = CheckIn.includes(:user, :reading_schedule, :flower).find(params[:id])

    render json: {
      id: check_in.id,
      user: {
        id: check_in.user.id,
        nickname: check_in.user.nickname,
        avatar_url: check_in.user.avatar_url
      },
      reading_schedule: {
        id: check_in.reading_schedule.id,
        day_number: check_in.reading_schedule.day_number,
        date: check_in.reading_schedule.date,
        reading_progress: check_in.reading_schedule.reading_progress
      },
      content: check_in.content,
      word_count: check_in.word_count,
      status: check_in.status,
      submitted_at: check_in.submitted_at,
      updated_at: check_in.updated_at,
      has_flower: check_in.has_flower?,
      flower: check_in.flower ? {
        giver: {
          id: check_in.flower.giver.id,
          nickname: check_in.flower.giver.nickname
        },
        comment: check_in.flower.comment,
        created_at: check_in.flower.created_at
      } : nil
    }
  end

  # PUT /api/check_ins/:id
  def update
    check_in = CheckIn.find(params[:id])

    # 只能修改自己的打卡
    unless check_in.user_id == current_user.id
      return render json: { error: "只能修改自己的打卡" }, status: :forbidden
    end

    # 如果已经获得小红花，不允许修改
    if check_in.has_flower?
      return render json: { error: "已获得小红花的打卡不允许修改" }, status: :unprocessable_entity
    end

    if check_in.update(check_in_params)
      render json: {
        id: check_in.id,
        content: check_in.content,
        word_count: check_in.word_count,
        status: check_in.status,
        updated_at: check_in.updated_at
      }
    else
      render json: { errors: check_in.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def check_in_params
    params.require(:check_in).permit(:content, :status)
  end
end
