module Api
  class EventsController < Api::ApplicationController
    skip_before_action :authenticate_user!, only: [:index, :show], raise: false
    include AdminAuthorizable

    # GET /api/events
    def index
      @events = ReadingEvent.includes(:leader).order(created_at: :desc)

      # 筛选条件
      @events = @events.where(status: params[:status]) if params[:status].present?

      render json: @events.map { |event| event_json(event) }
    end

    # GET /api/events/:id
    def show
      @event = ReadingEvent.includes(:leader, :participants).find(params[:id])

      render json: event_detail_json(@event)
    end

    # POST /api/events
    def create
      @event = current_user.created_events.new(event_params)
      @event.leader = current_user
      @event.approval_status = :pending  # 新活动默认待审批

      if @event.save
        # 自动生成阅读计划
        generate_reading_schedules(@event)

        render json: event_json(@event), status: :created
      else
        render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PUT /api/events/:id
    def update
      @event = current_user.created_events.find(params[:id])

      if @event.update(event_params)
        render json: event_json(@event)
      else
        render json: { errors: @event.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/events/:id
    def destroy
      @event = current_user.created_events.find(params[:id])
      @event.destroy

      head :no_content
    end

    # POST /api/events/:id/enroll
    def enroll
      @event = ReadingEvent.find(params[:id])

      # 使用EventEnrollmentService处理报名
      service_result = EventEnrollmentService.enroll_user!(@event, current_user)

      if service_result.success?
        render json: service_result.result, status: :created
      else
        render json: { error: service_result.first_error }, status: :unprocessable_entity
      end
    end

    # POST /api/events/:id/approve
    def approve
      @event = ReadingEvent.find(params[:id])

      # 检查是否有审批权限
      authorize_event_approval!

      # 使用EventManagementService处理审批
      service_result = EventManagementService.approve_event!(@event, current_user)

      if service_result.success?
        render json: service_result.result
      else
        render json: { error: service_result.first_error }, status: :unprocessable_entity
      end
    end

    # POST /api/events/:id/reject
    def reject
      @event = ReadingEvent.find(params[:id])

      # 检查是否有审批权限
      authorize_event_approval!

      # 使用EventManagementService处理拒绝
      service_result = EventManagementService.reject_event!(@event, current_user)

      if service_result.success?
        render json: service_result.result
      else
        render json: { error: service_result.first_error }, status: :unprocessable_entity
      end
    end

    # POST /api/events/:id/claim_leadership
    def claim_leadership
      @event = ReadingEvent.find(params[:id])
      schedule = @event.reading_schedules.find(params[:schedule_id])

      # 使用LeaderAssignmentService处理领读报名
      service_result = LeaderAssignmentService.claim_leadership!(@event, current_user, schedule)

      if service_result.success?
        render json: service_result.result
      else
        render json: { error: service_result.first_error }, status: :unprocessable_entity
      end
    end

    # POST /api/events/:id/complete
    def complete
      @event = ReadingEvent.find(params[:id])

      # 使用EventManagementService处理活动完成
      service_result = EventManagementService.complete_event!(@event, current_user)

      if service_result.success?
        render json: service_result.result
      else
        status_code = service_result.first_error.include?("只有") ? :forbidden : :unprocessable_entity
        render json: { error: service_result.first_error }, status: status_code
      end
    end

    # GET /api/events/:id/backup_needed
    def backup_needed
      @event = ReadingEvent.find(params[:id])

      # 检查是否是当前有效的小组长
      unless @event.current_leader?(current_user)
        return render json: { error: "只有活动小组长可以查看补位信息" }, status: :forbidden
      end

      backup_schedules = @event.schedules_need_backup

      render json: {
        event_id: @event.id,
        event_title: @event.title,
        backup_needed: backup_schedules,
        summary: {
          total_needing_backup: backup_schedules.count,
          missing_content_count: backup_schedules.count { |s| s[:missing_content] },
          missing_flowers_count: backup_schedules.count { |s| s[:missing_flowers] },
          urgent_count: backup_schedules.count { |s| s[:date] <= Date.today }
        },
        leader_permissions: {
          can_publish_content: true,
          can_give_flowers: true,
          backup_mechanism: "小组长全程具备领读权限，可随时补位"
        }
      }
    end

    private

    def event_params
      params.require(:event).permit(
        :title, :book_name, :book_cover_url, :description,
        :start_date, :end_date, :max_participants, :enrollment_fee, :status,
        :leader_assignment_type
      )
    end

    def event_json(event)
      {
        id: event.id,
        title: event.title,
        book_name: event.book_name,
        book_cover_url: event.book_cover_url,
        description: event.description,
        start_date: event.start_date,
        end_date: event.end_date,
        max_participants: event.max_participants,
        enrollment_fee: event.enrollment_fee,
        service_fee: event.service_fee,
        deposit: event.deposit,
        status: event.status,
        approval_status: event.approval_status,
        leader_assignment_type: event.leader_assignment_type,
        days_count: event.days_count,
        leader: {
          id: event.leader.id,
          nickname: event.leader.nickname,
          avatar_url: event.leader.avatar_url
        },
        approved_by: event.approved_by ? {
          id: event.approved_by.id,
          nickname: event.approved_by.nickname
        } : nil,
        approved_at: event.approved_at,
        created_at: event.created_at
      }
    end

    def event_detail_json(event)
      event_json(event).merge(
        participants_count: event.participants.count,
        participants: event.participants.map { |user|
          {
            id: user.id,
            nickname: user.nickname,
            avatar_url: user.avatar_url
          }
        }
      )
    end

    # enrollment_json方法已移至EventEnrollmentService

    def generate_reading_schedules(event)
      days_count = event.days_count

      days_count.times do |i|
        event.reading_schedules.create!(
          day_number: i + 1,
          date: event.start_date + i.days,
          reading_progress: "第 #{i + 1} 天阅读计划（待领读人填写）"
        )
      end
    end
  end
end
