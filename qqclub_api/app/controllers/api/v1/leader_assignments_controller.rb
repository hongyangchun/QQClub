class Api::V1::LeaderAssignmentsController < Api::V1::BaseController
  before_action :authenticate_user!
  before_action :set_reading_event
  before_action :check_event_permissions

  # POST /api/v1/reading_events/:reading_event_id/leader_assignments/auto_assign
  # 自动分配领读人
  def auto_assign
    assignment_type = params[:assignment_type]&.to_sym || @reading_event.leader_assignment_type.to_sym

    unless [:random, :balanced, :rotation, :voluntary].include?(assignment_type)
      render_error(
        message: '不支持的分配方式',
        code: 'UNSUPPORTED_ASSIGNMENT_TYPE',
        status: :unprocessable_entity
      )
      return
    end

    options = {}
    options[:max_leadership_count] = params[:max_leadership_count] if params[:max_leadership_count].present?
    options[:volunteer_assignments] = params[:volunteer_assignments] if params[:volunteer_assignments].present?

    service = LeaderAssignmentService.auto_assign_leaders!(@reading_event, assignment_type: assignment_type, options: options)

    if service.success?
      render_success(
        data: {
          assignment_type: service.result[:assignment_type],
          assigned_count: service.result[:assigned_count],
          statistics: get_assignment_statistics
        },
        message: service.result[:message]
      )
      log_api_call('leader_assignments#auto_assign')
    else
      render_error(
        message: service.error_message,
        code: 'AUTO_ASSIGN_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue => e
    render_error(
      message: '自动分配失败',
      errors: [e.message],
      code: 'AUTO_ASSIGN_ERROR'
    )
  end

  # POST /api/v1/reading_events/:reading_event_id/leader_assignments/:schedule_id/claim
  # 自由报名领读
  def claim_leadership
    schedule = @reading_event.reading_schedules.find(params[:schedule_id])

    service = LeaderAssignmentService.claim_leadership!(@reading_event, current_user, schedule)

    if service.success?
      render_success(
        data: service.result[:schedule_data],
        message: service.result[:message]
      )
      log_api_call('leader_assignments#claim_leadership')
    else
      render_error(
        message: service.error_message,
        code: 'CLAIM_LEADERSHIP_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '阅读计划不存在',
      code: 'SCHEDULE_NOT_FOUND',
      status: :not_found
    )
  rescue => e
    render_error(
      message: '报名领读失败',
      errors: [e.message],
      code: 'CLAIM_LEADERSHIP_ERROR'
    )
  end

  # POST /api/v1/reading_events/:reading_event_id/leader_assignments/:schedule_id/reassign
  # 重新分配领读人
  def reassign_leader
    schedule = @reading_event.reading_schedules.find(params[:schedule_id])

    unless params[:new_leader_id].present?
      render_error(
        message: '请指定新的领读人',
        code: 'NEW_LEADER_REQUIRED',
        status: :unprocessable_entity
      )
      return
    end

    new_leader = User.find(params[:new_leader_id])
    unless new_leader
      render_error(
        message: '新领读人不存在',
        code: 'NEW_LEADER_NOT_FOUND',
        status: :not_found
      )
      return
    end

    service = LeaderAssignmentService.reassign_leader!(@reading_event, schedule, new_leader)

    if service.success?
      render_success(
        data: service.result,
        message: service.result[:message]
      )
      log_api_call('leader_assignments#reassign_leader')
    else
      render_error(
        message: service.error_message,
        code: 'REASSIGN_LEADER_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '阅读计划或用户不存在',
      code: 'NOT_FOUND',
      status: :not_found
    )
  rescue => e
    render_error(
      message: '重新分配失败',
      errors: [e.message],
      code: 'REASSIGN_LEADER_ERROR'
    )
  end

  # POST /api/v1/reading_events/:reading_event_id/leader_assignments/:schedule_id/backup
  # 补位分配
  def backup_assignment
    schedule = @reading_event.reading_schedules.find(params[:schedule_id])

    unless params[:backup_leader_id].present?
      render_error(
        message: '请指定补位人',
        code: 'BACKUP_LEADER_REQUIRED',
        status: :unprocessable_entity
      )
      return
    end

    backup_leader = User.find(params[:backup_leader_id])
    unless backup_leader
      render_error(
        message: '补位人不存在',
        code: 'BACKUP_LEADER_NOT_FOUND',
        status: :not_found
      )
      return
    end

    service = LeaderAssignmentService.backup_assignment!(@reading_event, schedule, backup_leader)

    if service.success?
      render_success(
        data: service.result,
        message: service.result[:message]
      )
      log_api_call('leader_assignments#backup_assignment')
    else
      render_error(
        message: service.error_message,
        code: 'BACKUP_ASSIGNMENT_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '阅读计划或用户不存在',
      code: 'NOT_FOUND',
      status: :not_found
    )
  rescue => e
    render_error(
      message: '补位分配失败',
      errors: [e.message],
      code: 'BACKUP_ASSIGNMENT_ERROR'
    )
  end

  # GET /api/v1/reading_events/:reading_event_id/leader_assignments/statistics
  # 获取领读分配统计
  def statistics
    service = LeaderAssignmentService.assignment_statistics(@reading_event)

    if service.success?
      render_success(
        data: service.result
      )
      log_api_call('leader_assignments#statistics')
    else
      render_error(
        message: service.error_message,
        code: 'STATISTICS_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue => e
    render_error(
      message: '获取统计失败',
      errors: [e.message],
      code: 'STATISTICS_ERROR'
    )
  end

  # GET /api/v1/reading_events/:reading_event_id/leader_assignments/backup_needed
  # 获取需要补位的日程
  def backup_needed
    backup_schedules = @reading_event.schedules_need_backup

    schedule_data = backup_schedules.map do |backup_info|
      {
        schedule: {
          id: backup_info[:schedule].id,
          day_number: backup_info[:schedule].day_number,
          date: backup_info[:schedule].date,
          reading_progress: backup_info[:schedule].reading_progress
        },
        leader: backup_info[:leader] ? {
          id: backup_info[:leader].id,
          nickname: backup_info[:leader].nickname,
          avatar_url: backup_info[:leader].avatar_url
        } : nil,
        backup_priority: backup_info[:backup_priority],
        missing_content: backup_info[:missing_content],
        missing_flowers: backup_info[:missing_flowers],
        needs_backup: backup_info[:needs_backup],
        content_deadline: backup_info[:content_deadline],
        flowers_deadline: backup_info[:flowers_deadline]
      }
    end

    render_success(
      data: {
        backup_schedules: schedule_data,
        total_needing_backup: schedule_data.count,
        content_deadline_soon: schedule_data.select { |s| s[:missing_content] && s[:content_deadline] <= Date.today + 1.day }.count,
        flowers_deadline_soon: schedule_data.select { |s| s[:missing_flowers] && s[:flowers_deadline] <= Date.today + 1.day }.count
      }
    )
    log_api_call('leader_assignments#backup_needed')
  rescue => e
    render_error(
      message: '获取补位信息失败',
      errors: [e.message],
      code: 'BACKUP_NEEDED_ERROR'
    )
  end

  # GET /api/v1/reading_events/:reading_event_id/leader_assignments/permissions
  # 检查领读权限
  def check_permissions
    schedule = params[:schedule_id] ? @reading_event.reading_schedules.find(params[:schedule_id]) : nil

    service = LeaderAssignmentService.check_permissions(@reading_event, current_user, schedule)

    if service.success?
      render_success(
        data: service.result
      )
      log_api_call('leader_assignments#check_permissions')
    else
      render_error(
        message: service.error_message,
        code: 'PERMISSION_CHECK_FAILED',
        status: :unprocessable_entity
      )
    end
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '阅读计划不存在',
      code: 'SCHEDULE_NOT_FOUND',
      status: :not_found
    )
  rescue => e
    render_error(
      message: '权限检查失败',
      errors: [e.message],
      code: 'PERMISSION_CHECK_ERROR'
    )
  end

  private

  def set_reading_event
    event_id = params[:reading_event_id]
    @reading_event = ReadingEvent.find(event_id)
  rescue ActiveRecord::RecordNotFound
    render_error(
      message: '活动不存在',
      code: 'EVENT_NOT_FOUND',
      status: :not_found
    )
  end

  def check_event_permissions
    unless @reading_event.leader == current_user
      render_error(
        message: '只有活动创建者可以管理领读分配',
        code: 'FORBIDDEN',
        status: :forbidden
      )
    end
  end

  def get_assignment_statistics
    service = LeaderAssignmentService.assignment_statistics(@reading_event)
    service.success? ? service.result : {}
  end
end