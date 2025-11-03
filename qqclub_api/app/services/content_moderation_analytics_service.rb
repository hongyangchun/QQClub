# frozen_string_literal: true

# ContentModerationAnalyticsService - 内容审核统计分析服务
# 专门负责举报数据的统计、分析和报告生成
class ContentModerationAnalyticsService < ApplicationService
  include ServiceInterface
  attr_reader :start_date, :end_date, :options

  def initialize(start_date: nil, end_date: nil, options: {})
    super()
    @start_date = start_date || 30.days.ago.to_date
    @end_date = end_date || Date.current
    @options = options.with_indifferent_access
  end

  # 获取综合统计报告
  def call
    handle_errors do
      validate_date_params
      generate_comprehensive_report
    end
    self
  end

  # 获取基本统计数据
  def self.get_basic_statistics(days = 30)
    new(
      start_date: days.days.ago.to_date,
      end_date: Date.current
    ).basic_statistics
  end

  # 生成审核报告
  def self.generate_moderation_report(start_date = nil, end_date = nil)
    new(
      start_date: start_date,
      end_date: end_date
    ).generate_moderation_report
  end

  private

  # 验证日期参数
  def validate_date_params
    return failure!("开始日期不能为空") unless start_date
    return failure!("结束日期不能为空") unless end_date
    return failure!("开始日期不能晚于结束日期") if start_date > end_date
    return failure!("时间范围不能超过一年") if (end_date - start_date).days > 365

    true
  end

  # 生成综合报告
  def generate_comprehensive_report
    reports = find_reports_in_period

    success!({
      period: {
        start: start_date,
        end: end_date,
        days_count: (end_date - start_date).to_i + 1
      },
      summary: generate_summary_statistics(reports),
      trends: generate_trend_analysis(reports),
      breakdown: generate_breakdown_analysis(reports),
      efficiency: generate_efficiency_metrics(reports),
      recommendations: generate_recommendations(reports)
    })
  end

  # 查找时间范围内的举报
  def find_reports_in_period
    ContentReport.where(
      created_at: start_date.beginning_of_day..end_date.end_of_day
    ).includes(:user, :admin, :target_content)
  end

  # 生成摘要统计
  def generate_summary_statistics(reports)
    {
      total_reports: reports.count,
      pending_reports: reports.pending.count,
      processed_reports: reports.where.not(status: :pending).count,
      auto_processed_reports: reports.where.not(admin_id: nil).where('reports.created_at = reports.updated_at').count,
      average_processing_time: calculate_average_processing_time(reports),
      reports_per_day: (reports.count.to_f / ((end_date - start_date).to_i + 1)).round(2)
    }
  end

  # 生成趋势分析
  def generate_trend_analysis(reports)
    {
      daily_trends: reports.group('DATE(created_at)').count,
      weekly_trends: generate_weekly_trends(reports),
      monthly_trends: generate_monthly_trends(reports),
      peak_hours: identify_peak_hours(reports),
      growth_rate: calculate_growth_rate(reports)
    }
  end

  # 生成周趋势
  def generate_weekly_trends(reports)
    reports.group("strftime('%Y-%W', created_at)").count
  end

  # 生成月趋势
  def generate_monthly_trends(reports)
    reports.group("strftime('%Y-%m', created_at)").count
  end

  # 识别举报高峰时段
  def identify_peak_hours(reports)
    reports.group("strftime('%H', created_at)").count.sort_by { |_, count| -count }.first(5)
  end

  # 计算增长率
  def calculate_growth_rate(reports)
    return {} if reports.count < 2

    first_half = reports.where(created_at: start_date..(start_date + ((end_date - start_date) / 2)))
    second_half = reports.where(created_at: ((start_date + ((end_date - start_date) / 2) + 1.day))..end_date)

    {
      first_half_count: first_half.count,
      second_half_count: second_half.count,
      growth_rate: calculate_percentage_change(first_half.count, second_half.count)
    }
  end

  # 生成分类分析
  def generate_breakdown_analysis(reports)
    {
      by_reason: reports.group(:reason).count,
      by_status: reports.group(:status).count,
      by_content_type: reports.joins(:target_content).group('target_contents.type').count,
      by_admin: reports.joins(:admin).where.not(admin_id: nil).group('users.nickname').count,
      by_reporter: reports.joins(:user).group('users.nickname').count.order('count DESC').limit(10),
      by_action_taken: reports.joins(:target_content).where(target_contents: { hidden: true }).count
    }
  end

  # 生成效率指标
  def generate_efficiency_metrics(reports)
    processed_reports = reports.where.not(status: :pending)

    {
      processing_rate: calculate_processing_rate(reports),
      average_resolution_time: calculate_average_processing_time(processed_reports),
      auto_processing_rate: calculate_auto_processing_rate(reports),
      admin_workload: calculate_admin_workload(reports),
      repeat_content_reports: calculate_repeat_content_reports(reports)
    }
  end

  # 计算处理率
  def calculate_processing_rate(reports)
    return 0 if reports.count == 0
    processed = reports.where.not(status: :pending).count
    (processed.to_f / reports.count * 100).round(2)
  end

  # 计算平均处理时间
  def calculate_average_processing_time(reports)
    return 0 if reports.empty?

    processed_reports = reports.where.not(status: :pending).where.not(updated_at: nil)
    return 0 if processed_reports.empty?

    total_time = processed_reports.sum do |report|
      (report.updated_at - report.created_at) / 1.hour # 转换为小时
    end

    (total_time / processed_reports.count).round(2)
  end

  # 计算自动处理率
  def calculate_auto_processing_rate(reports)
    return 0 if reports.count == 0

    auto_processed = reports.where.not(admin_id: nil)
                          .where('reports.created_at = reports.updated_at')
                          .count

    (auto_processed.to_f / reports.count * 100).round(2)
  end

  # 计算管理员工作量
  def calculate_admin_workload(reports)
    reports.joins(:admin)
           .where.not(admin_id: nil)
           .group('users.nickname')
           .count
  end

  # 计算重复内容举报
  def calculate_repeat_content_reports(reports)
    content_counts = reports.group(:target_content_id).count
    repeated_contents = content_counts.select { |_, count| count > 1 }

    {
      total_repeated_contents: repeated_contents.count,
      average_reports_per_content: repeated_contents.empty? ? 0 :
        (repeated_contents.values.sum.to_f / repeated_contents.count).round(2),
      most_reported_content: repeated_contents.max_by { |_, count| count }
    }
  end

  # 生成建议
  def generate_recommendations(reports)
    recommendations = []

    # 分析处理效率
    processing_rate = calculate_processing_rate(reports)
    if processing_rate < 80
      recommendations << {
        type: 'efficiency',
        priority: 'high',
        title: '提高举报处理效率',
        description: "当前处理率为#{processing_rate}%，建议优化审核流程或增加审核人员"
      }
    end

    # 分析自动处理效果
    auto_rate = calculate_auto_processing_rate(reports)
    if auto_rate < 30
      recommendations << {
        type: 'automation',
        priority: 'medium',
        title: '增加自动化处理',
        description: "当前自动处理率为#{auto_rate}%，建议增加敏感词检测等自动化规则"
      }
    end

    # 分析举报类型分布
    reason_breakdown = reports.group(:reason).count
    if reason_breakdown['sensitive_words']&.to_i&.>(reason_breakdown.values.sum * 0.4)
      recommendations << {
        type: 'prevention',
        priority: 'high',
        title: '加强敏感词预防',
        description: '敏感词举报占比较高，建议在内容发布时进行更好的预检查'
      }
    end

    recommendations
  end

  # 基本统计数据
  def basic_statistics
    reports = find_reports_in_period

    {
      total_reports: reports.count,
      pending_reports: reports.pending.count,
      processed_reports: reports.where.not(status: :pending).count,
      by_reason: reports.group(:reason).count,
      by_status: reports.group(:status).count
    }
  end

  # 生成审核报告
  def generate_moderation_report
    reports = find_reports_in_period

    {
      period: { start: start_date, end: end_date },
      summary: {
        total_reports: reports.count,
        pending_reports: reports.pending.count,
        processed_reports: reports.where.not(status: :pending).count,
        auto_processed_reports: reports.where.not(admin_id: nil).count
      },
      by_reason: reports.group(:reason).count,
      by_status: reports.group(:status).count,
      by_admin: reports.joins(:admin).group('users.nickname').count,
      daily_trends: reports.group('DATE(created_at)').count
    }
  end

  # 计算百分比变化
  def calculate_percentage_change(old_value, new_value)
    return 0 if old_value == 0
    (((new_value - old_value).to_f / old_value) * 100).round(2)
  end
end