class Api::FlowersController < ApplicationController
  include Authenticable

  # POST /api/check_ins/:check_in_id/flower
  def create
    check_in = CheckIn.find(params[:check_in_id])
    reading_schedule = check_in.reading_schedule
    event = reading_schedule.reading_event

    # 不能给自己的打卡送花
    if check_in.user_id == current_user.id
      return render json: { error: "不能给自己送小红花" }, status: :unprocessable_entity
    end

    # 检查是否有权限发放小红花（当天和后一天权限 + 小组长补位）
    unless event.can_give_flowers?(current_user, reading_schedule)
      return render json: {
        error: "只有领读人或小组长可以发放小红花",
        details: {
          leader_permission: "领读人可在当天或后一天发放",
          group_leader_permission: "小组长全程具备发放权限（补位机制）",
          current_user_role: event.current_leader?(current_user) ? "小组长" : "普通用户",
          flower_window: "小红花发放窗口灵活，支持补位机制"
        }
      }, status: :forbidden
    end

    flower = Flower.new(flower_params)
    flower.check_in = check_in
    flower.giver = current_user
    flower.recipient = check_in.user
    flower.reading_schedule = reading_schedule

    if flower.save
      render json: {
        id: flower.id,
        check_in_id: flower.check_in_id,
        giver: {
          id: flower.giver.id,
          nickname: flower.giver.nickname,
          avatar_url: flower.giver.avatar_url
        },
        recipient: {
          id: flower.recipient.id,
          nickname: flower.recipient.nickname,
          avatar_url: flower.recipient.avatar_url
        },
        comment: flower.comment,
        flower_window: "领读人可在当天或后一天发放小红花",
        created_at: flower.created_at
      }, status: :created
    else
      render json: { error: flower.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /api/reading_schedules/:reading_schedule_id/flowers
  def index
    reading_schedule = ReadingSchedule.find(params[:reading_schedule_id])
    flowers = reading_schedule.flowers.includes(:giver, :recipient, :check_in)

    render json: flowers.map { |flower|
      {
        id: flower.id,
        giver: {
          id: flower.giver.id,
          nickname: flower.giver.nickname,
          avatar_url: flower.giver.avatar_url
        },
        recipient: {
          id: flower.recipient.id,
          nickname: flower.recipient.nickname,
          avatar_url: flower.recipient.avatar_url
        },
        check_in: {
          id: flower.check_in.id,
          content: flower.check_in.content.truncate(100)
        },
        comment: flower.comment,
        created_at: flower.created_at
      }
    }
  end

  # GET /api/users/:user_id/flowers
  def user_flowers
    user = User.find(params[:user_id])
    flowers = Flower.where(recipient: user).includes(:giver, :reading_schedule, :check_in)

    render json: {
      total_count: flowers.count,
      flowers: flowers.map { |flower|
        {
          id: flower.id,
          giver: {
            id: flower.giver.id,
            nickname: flower.giver.nickname,
            avatar_url: flower.giver.avatar_url
          },
          reading_schedule: {
            id: flower.reading_schedule.id,
            day_number: flower.reading_schedule.day_number,
            date: flower.reading_schedule.date
          },
          check_in: {
            id: flower.check_in.id,
            content: flower.check_in.content.truncate(100)
          },
          comment: flower.comment,
          created_at: flower.created_at
        }
      }
    }
  end

  private

  def flower_params
    params.require(:flower).permit(:comment)
  end
end
