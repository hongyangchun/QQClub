# 内容导出服务
# 提供打卡内容的多格式导出功能
class ContentExportService
  require 'prawn' # PDF生成
  require 'prawn/table' # PDF表格
  require 'csv' # CSV导出

  class ExportOptions
    attr_accessor :format, :check_in_ids, :user_id, :event_id, :date_from, :date_to,
                  :include_metadata, :include_comments, :include_flowers,
                  :sort_by, :sort_direction, :template

    def initialize(params = {})
      @format = params[:format] || 'pdf'
      @check_in_ids = params[:check_in_ids]&.split(',')&.map(&:to_i)
      @user_id = params[:user_id]&.to_i
      @event_id = params[:event_id]&.to_i
      @date_from = parse_date(params[:date_from])
      @date_to = parse_date(params[:date_to])
      @include_metadata = params[:include_metadata] != 'false'
      @include_comments = params[:include_comments] == 'true'
      @include_flowers = params[:include_flowers] == 'true'
      @sort_by = params[:sort_by] || 'created_at'
      @sort_direction = params[:sort_direction] || 'desc'
      @template = params[:template] || 'default'
    end

    def valid_format?
      %w[pdf markdown html txt csv].include?(format)
    end

    private

    def parse_date(date_string)
      return nil if date_string.blank?
      Date.parse(date_string)
    rescue ArgumentError, TypeError
      nil
    end
  end

  class ExportResult
    attr_accessor :content, :filename, :content_type, :size, :check_ins_count

    def initialize
      @content = ''
      @filename = ''
      @content_type = 'application/octet-stream'
      @size = 0
      @check_ins_count = 0
    end

    def success?
      !content.empty?
    end
  end

  class << self
    # 主要导出方法
    def export(params = {})
      options = ExportOptions.new(params)

      unless options.valid_format?
        result = ExportResult.new
        result.filename = "export_error.txt"
        result.content = "不支持的导出格式: #{options.format}"
        result.content_type = "text/plain"
        return result
      end

      # 获取要导出的打卡记录
      check_ins = get_check_ins_for_export(options)

      if check_ins.empty?
        result = ExportResult.new
        result.filename = "empty_export.#{options.format}"
        result.content = "没有找到符合条件的打卡记录"
        result.content_type = "text/plain"
        return result
      end

      # 根据格式执行导出
      result = case options.format
               when 'pdf'
                 export_to_pdf(check_ins, options)
               when 'markdown'
                 export_to_markdown(check_ins, options)
               when 'html'
                 export_to_html(check_ins, options)
               when 'txt'
                 export_to_text(check_ins, options)
               when 'csv'
                 export_to_csv(check_ins, options)
               else
                 export_to_text(check_ins, options)
               end

      result.check_ins_count = check_ins.count
      result
    rescue => e
      result = ExportResult.new
      result.filename = "export_error.txt"
      result.content = "导出过程中发生错误: #{e.message}"
      result.content_type = "text/plain"
      result
    end

    # 批量导出
    def batch_export(params_array = [])
      results = []

      params_array.each_with_index do |params, index|
        result = export(params)
        result.filename = "batch_export_#{index + 1}_#{result.filename}"
        results << result
      end

      results
    end

    # 获取导出统计信息
    def export_statistics(params = {})
      options = ExportOptions.new(params)
      check_ins = get_check_ins_for_export(options)

      {
        total_check_ins: check_ins.count,
        total_words: check_ins.sum(:word_count),
        date_range: {
          from: check_ins.minimum(:created_at)&.to_date,
          to: check_ins.maximum(:created_at)&.to_date
        },
        users_count: check_ins.distinct.count(:user_id),
        events_count: check_ins.joins(:reading_event).distinct.count(:reading_event_id),
        format_options: %w[pdf markdown html txt csv]
      }
    end

    private

    # 获取要导出的打卡记录
    def get_check_ins_for_export(options)
      query = CheckIn.includes(:user, :reading_schedule, :reading_event, :flowers, :comments)

      # 按ID筛选
      if options.check_in_ids.present?
        query = query.where(id: options.check_in_ids)
      end

      # 按用户筛选
      if options.user_id.present?
        query = query.where(user_id: options.user_id)
      end

      # 按活动筛选
      if options.event_id.present?
        query = query.joins(:reading_schedule).where(reading_schedules: { reading_event_id: options.event_id })
      end

      # 按日期范围筛选
      if options.date_from.present?
        query = query.where('check_ins.created_at >= ?', options.date_from.beginning_of_day)
      end

      if options.date_to.present?
        query = query.where('check_ins.created_at <= ?', options.date_to.end_of_day)
      end

      # 排序
      case options.sort_by
      when 'created_at'
        query = query.order("created_at #{options.sort_direction.upcase}")
      when 'word_count'
        query = query.order("word_count #{options.sort_direction.upcase}")
      when 'flowers_count'
        query = query.left_joins(:flowers).group('check_ins.id').order("COUNT(flowers.id) #{options.sort_direction.upcase}")
      else
        query = order(created_at: :desc)
      end

      query
    end

    # 导出为PDF
    def export_to_pdf(check_ins, options)
      result = ExportResult.new

      # 创建PDF文档
      Prawn::Document.generate(StringIO.new) do |pdf|
        # 设置字体
        pdf.font_families.update(
          'NotoSansCJK' => {
            normal: Rails.root.join('app', 'assets', 'fonts', 'NotoSansCJK-Regular.ttc'),
            bold: Rails.root.join('app', 'assets', 'fonts', 'NotoSansCJK-Bold.ttc')
          }
        )
        pdf.font 'NotoSansCJK'

        # 标题
        pdf.text '打卡内容导出', size: 24, style: :bold, align: :center
        pdf.move_down 20

        # 导出信息
        if options.include_metadata
          pdf.text "导出时间: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}", size: 10
          pdf.text "打卡数量: #{check_ins.count}", size: 10
          pdf.text "总字数: #{check_ins.sum(:word_count)}", size: 10
          pdf.move_down 20
        end

        # 打卡内容
        check_ins.each_with_index do |check_in, index|
          pdf.start_new_page if index > 0

          # 打卡标题
          pdf.text "打卡 ##{index + 1}", size: 16, style: :bold
          pdf.text "用户: #{check_in.user.nickname}", size: 12
          pdf.text "时间: #{check_in.created_at.strftime('%Y-%m-%d %H:%M')}", size: 12
          pdf.text "字数: #{check_in.word_count}", size: 12
          pdf.text "状态: #{check_in.status_text}", size: 12
          pdf.move_down 10

          # 打卡内容
          pdf.text "内容:", size: 14, style: :bold
          pdf.text check_in.content, size: 12
          pdf.move_down 10

          # 小红花
          if options.include_flowers && check_in.flowers.any?
            pdf.text "小红花:", size: 14, style: :bold
            check_in.flowers.each do |flower|
              pdf.text "- #{flower.giver.nickname}: #{flower.comment}", size: 10
            end
            pdf.move_down 10
          end

          # 评论
          if options.include_comments && check_in.comments.any?
            pdf.text "评论:", size: 14, style: :bold
            check_in.comments.each do |comment|
              pdf.text "- #{comment.user.nickname}: #{comment.content}", size: 10
            end
          end

          pdf.move_down 20
        end
      end.string

      result.content = pdf_content
      result.filename = "check_ins_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.pdf"
      result.content_type = 'application/pdf'
      result
    end

    # 导出为Markdown
    def export_to_markdown(check_ins, options)
      result = ExportResult.new
      content = []

      # Markdown头部
      content << "# 打卡内容导出"
      content << ""
      content << "**导出时间**: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
      content << "**打卡数量**: #{check_ins.count}"
      content << "**总字数**: #{check_ins.sum(:word_count)}"
      content << ""

      # 打卡内容
      check_ins.each_with_index do |check_in, index|
        content << "## 打卡 ##{index + 1}"
        content << ""
        content << "**用户**: #{check_in.user.nickname}"
        content << "**时间**: #{check_in.created_at.strftime('%Y-%m-%d %H:%M')}"
        content << "**字数**: #{check_in.word_count}"
        content << "**状态**: #{check_in.status_text}"
        content << ""

        content << "### 内容"
        content << ""
        content << check_in.content
        content << ""

        # 小红花
        if options.include_flowers && check_in.flowers.any?
          content << "### 小红花"
          content << ""
          check_in.flowers.each do |flower|
            content << "- **#{flower.giver.nickname}**: #{flower.comment}"
          end
          content << ""
        end

        # 评论
        if options.include_comments && check_in.comments.any?
          content << "### 评论"
          content << ""
          check_in.comments.each do |comment|
            content << "- **#{comment.user.nickname}**: #{comment.content}"
          end
          content << ""
        end

        content << "---"
        content << ""
      end

      result.content = content.join("\n")
      result.filename = "check_ins_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.md"
      result.content_type = 'text/markdown'
      result
    end

    # 导出为HTML
    def export_to_html(check_ins, options)
      result = ExportResult.new

      html = <<~HTML
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>打卡内容导出</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans CJK SC', sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 20px; }
            .header { border-bottom: 2px solid #eee; padding-bottom: 20px; margin-bottom: 30px; }
            .check-in { border: 1px solid #ddd; border-radius: 8px; padding: 20px; margin-bottom: 20px; }
            .check-in-header { border-bottom: 1px solid #eee; padding-bottom: 10px; margin-bottom: 15px; }
            .user-info { color: #666; font-size: 14px; margin-bottom: 5px; }
            .content { margin: 15px 0; }
            .flowers, .comments { margin-top: 15px; padding: 10px; background: #f9f9f9; border-radius: 4px; }
            .flower-item, .comment-item { margin: 5px 0; font-size: 14px; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>打卡内容导出</h1>
            <p><strong>导出时间</strong>: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}</p>
            <p><strong>打卡数量</strong>: #{check_ins.count}</p>
            <p><strong>总字数</strong>: #{check_ins.sum(:word_count)}</p>
          </div>

          <div class="check-ins">
      HTML

      check_ins.each_with_index do |check_in, index|
        html += <<~HTML
            <div class="check-in">
              <div class="check-in-header">
                <h2>打卡 ##{index + 1}</h2>
                <div class="user-info">
                  <span><strong>用户</strong>: #{check_in.user.nickname}</span> |
                  <span><strong>时间</strong>: #{check_in.created_at.strftime('%Y-%m-%d %H:%M')}</span> |
                  <span><strong>字数</strong>: #{check_in.word_count}</span> |
                  <span><strong>状态</strong>: #{check_in.status_text}</span>
                </div>
              </div>
              <div class="content">
                <h3>内容</h3>
                <div>#{check_in.content.gsub("\n", "<br>")}</div>
              </div>
        HTML

        # 小红花
        if options.include_flowers && check_in.flowers.any?
          html += <<~HTML
              <div class="flowers">
                <h4>小红花</h4>
                #{check_in.flowers.map { |flower| "<div class=\"flower-item\"><strong>#{flower.giver.nickname}</strong>: #{flower.comment}</div>" }.join}
              </div>
          HTML
        end

        # 评论
        if options.include_comments && check_in.comments.any?
          html += <<~HTML
              <div class="comments">
                <h4>评论</h4>
                #{check_in.comments.map { |comment| "<div class=\"comment-item\"><strong>#{comment.user.nickname}</strong>: #{comment.content}</div>" }.join}
              </div>
          HTML
        end

        html += "</div>"
      end

      html += <<~HTML
          </div>
        </body>
        </html>
      HTML

      result.content = html
      result.filename = "check_ins_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.html"
      result.content_type = 'text/html'
      result
    end

    # 导出为纯文本
    def export_to_text(check_ins, options)
      result = ExportResult.new
      content = []

      # 文本头部
      content << "=" * 60
      content << "打卡内容导出"
      content << "=" * 60
      content << ""
      content << "导出时间: #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
      content << "打卡数量: #{check_ins.count}"
      content << "总字数: #{check_ins.sum(:word_count)}"
      content << ""

      # 打卡内容
      check_ins.each_with_index do |check_in, index|
        content << "-" * 40
        content << "打卡 ##{index + 1}"
        content << "-" * 40
        content << "用户: #{check_in.user.nickname}"
        content << "时间: #{check_in.created_at.strftime('%Y-%m-%d %H:%M')}"
        content << "字数: #{check_in.word_count}"
        content << "状态: #{check_in.status_text}"
        content << ""
        content << "内容:"
        content << check_in.content
        content << ""

        # 小红花
        if options.include_flowers && check_in.flowers.any?
          content << "小红花:"
          check_in.flowers.each do |flower|
            content << "- #{flower.giver.nickname}: #{flower.comment}"
          end
          content << ""
        end

        # 评论
        if options.include_comments && check_in.comments.any?
          content << "评论:"
          check_in.comments.each do |comment|
            content << "- #{comment.user.nickname}: #{comment.content}"
          end
          content << ""
        end

        content << ""
      end

      result.content = content.join("\n")
      result.filename = "check_ins_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.txt"
      result.content_type = 'text/plain'
      result
    end

    # 导出为CSV
    def export_to_csv(check_ins, options)
      result = ExportResult.new

      CSV.generate(headers: true, write_headers: true) do |csv|
        headers = ['ID', '用户', '时间', '字数', '状态', '内容']
        headers += ['小红花数量'] if options.include_flowers
        headers += ['评论数量'] if options.include_comments

        csv << headers

        check_ins.each do |check_in|
          row = [
            check_in.id,
            check_in.user.nickname,
            check_in.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            check_in.word_count,
            check_in.status_text,
            check_in.content.gsub("\n", " ")
          ]

          if options.include_flowers
            row << check_in.flowers.count
          end

          if options.include_comments
            row << check_in.comments.count
          end

          csv << row
        end
      end

      result.content = csv_content
      result.filename = "check_ins_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
      result.content_type = 'text/csv'
      result
    end
  end
end

# 扩展CheckIn模型以支持导出
class CheckIn
  def status_text
    case status
    when 'normal'
      '正常打卡'
    when 'supplement'
      '补卡'
    when 'late'
      '迟到'
    else
      status.to_s
    end
  end
end