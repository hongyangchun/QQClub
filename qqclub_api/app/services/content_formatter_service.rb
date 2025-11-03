# 内容格式化服务
# 负责处理打卡内容的格式化、分段、表情转换等
class ContentFormatterService
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::SanitizeHelper

  # 表情符号映射
  EMOJI_MAPPING = {
    '开心' => '😊',
    '快乐' => '😄',
    '哈哈' => '😂',
    '喜欢' => '❤️',
    '爱' => '💕',
    '赞' => '👍',
    '加油' => '💪',
    '思考' => '🤔',
    '学习' => '📚',
    '阅读' => '📖',
    '进步' => '📈',
    '努力' => '🌟',
    '感谢' => '🙏',
    '棒' => '👏',
    '好' => '👌',
    '支持' => '💯',
    '鼓励' => '🎉',
    '收获' => '🌱',
    '成长' => '🌿'
  }.freeze

  # 敏感词列表（简化版）
  SENSITIVE_WORDS = %w[
    违法 暴力 色情 赌博 毒品
    # 实际应用中应该使用更完整的敏感词库
  ].freeze

  class << self
    # 格式化内容主体方法
    def format(content, options = {})
      formatted_content = content.dup

      # 应用各种格式化处理
      formatted_content = sanitize_content(formatted_content)
      formatted_content = convert_emojis(formatted_content)
      formatted_content = format_paragraphs(formatted_content)
      formatted_content = highlight_keywords(formatted_content, options[:keywords]) if options[:keywords].present?
      formatted_content = add_hashtag_links(formatted_content) if options[:enable_hashtags]
      formatted_content = truncate_content(formatted_content, options[:length]) if options[:length].present?

      formatted_content
    end

    # 生成内容摘要
    def generate_summary(content, max_length = 200)
      # 清理内容并生成摘要
      cleaned = sanitize_content(content)
      cleaned = remove_formatting(cleaned)

      if cleaned.length > max_length
        # 尝试在句号或换行符处截断
        truncated = cleaned.truncate(max_length, separator: /[,，.。!！?？\n]/)
        truncated += "..." unless truncated.end_with?('.')
        truncated
      else
        cleaned
      end
    end

    # 提取关键词
    def extract_keywords(content, max_keywords = 5)
      cleaned = sanitize_content(content)

      # 简单的关键词提取逻辑（实际应用中可以使用更复杂的NLP算法）
      words = cleaned.scan(/[\u4e00-\u9fa5]+|[a-zA-Z]+/)
                      .reject { |word| word.length < 2 }
                      .group_by(&:itself)
                      .transform_values(&:count)
                      .sort_by { |_, count| -count }
                      .first(max_keywords)
                      .map(&:first)

      words
    end

    # 计算内容质量分数
    def calculate_quality_score(content)
      score = 0

      # 基础分数（长度要求）
      length = content.length
      if length >= 50
        score += 10
      elsif length >= 100
        score += 20
      elsif length >= 200
        score += 30
      end

      # 段落结构分数
      paragraphs = content.split(/\n\n+/).length
      score += [paragraphs * 2, 10].min

      # 关键词多样性分数
      keywords = extract_keywords(content, 10).length
      score += keywords * 2

      # 表情符号使用分数
      emoji_count = content.scan(/[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]/).length
      score += [emoji_count, 5].min

      # 敏感词检测扣分
      sensitive_count = count_sensitive_words(content)
      score -= sensitive_count * 10

      [score, 0].max # 确保分数不为负
    end

    # 检查内容合规性
    def check_compliance(content)
      issues = []

      # 检查敏感词
      sensitive_words = find_sensitive_words(content)
      if sensitive_words.any?
        issues << {
          type: 'sensitive_words',
          message: "内容包含敏感词：#{sensitive_words.join(', ')}",
          severity: 'high'
        }
      end

      # 检查长度
      if content.length < 50
        issues << {
          type: 'too_short',
          message: "内容太短，至少需要50个字",
          severity: 'medium'
        }
      end

      # 检查是否为重复内容
      if is_duplicate_content?(content)
        issues << {
          type: 'duplicate',
          message: "内容疑似重复",
          severity: 'low'
        }
      end

      # 检查格式
      if content.match?(/^[^\n]*$/) # 没有换行
        issues << {
          type: 'poor_formatting',
          message: "建议分段以提高可读性",
          severity: 'low'
        }
      end

      {
        compliant: issues.empty?,
        issues: issues,
        score: calculate_quality_score(content)
      }
    end

    private

    # 清理内容，移除不安全的HTML
    def sanitize_content(content)
      # 简单的HTML清理实现
      cleaned = content.dup
      cleaned.gsub!(/<script[^>]*>.*?<\/script>/mi, '')
      cleaned.gsub!(/<style[^>]*>.*?<\/style>/mi, '')
      cleaned.gsub!(/<[^>]*>/, '')
      cleaned.strip
    end

    # 转换表情符号
    def convert_emojis(content)
      formatted = content.dup

      EMOJI_MAPPING.each do |text, emoji|
        formatted.gsub!(/#{text}/i, emoji)
      end

      formatted
    end

    # 格式化段落
    def format_paragraphs(content)
      # 将连续的换行符转换为段落
      paragraphs = content.split(/\n\n+/)

      formatted_paragraphs = paragraphs.map do |paragraph|
        # 处理单个段落内的换行
        lines = paragraph.split(/\n/)

        if lines.length == 1
          # 单行内容
          "<p>#{lines.first.strip}</p>"
        else
          # 多行内容，使用<br>连接
          "<p>#{lines.map(&:strip).join('<br>')}</p>"
        end
      end

      formatted_paragraphs.join("\n")
    end

    # 高亮关键词
    def highlight_keywords(content, keywords)
      formatted = content.dup

      Array(keywords).each do |keyword|
        next if keyword.blank?
        formatted.gsub!(/(#{Regexp.escape(keyword)})/i, '<mark>\1</mark>')
      end

      formatted
    end

    # 添加话题标签链接
    def add_hashtag_links(content)
      content.gsub(/#([^#\s]+)#?/) do |match|
        hashtag = $1
        "<a href='/search?q=%23#{hashtag}' class='hashtag'>##{hashtag}</a>"
      end
    end

    # 截断内容
    def truncate_content(content, length)
      # 简单的截断实现
      if content.length > length
        last_space = content.rindex(' ', length - 3)
        if last_space && last_space > 0
          content[0, last_space] + "..."
        else
          content[0, length - 3] + "..."
        end
      else
        content
      end
    end

    # 移除格式化标签
    def remove_formatting(content)
      # 移除所有HTML标签
      content.gsub(/<[^>]*>/, '').strip
    end

    # 统计敏感词数量
    def count_sensitive_words(content)
      count = 0
      SENSITIVE_WORDS.each do |word|
        count += content.scan(/#{word}/i).length
      end
      count
    end

    # 查找敏感词
    def find_sensitive_words(content)
      found_words = []

      SENSITIVE_WORDS.each do |word|
        if content.match?(/#{word}/i)
          found_words << word
        end
      end

      found_words
    end

    # 检查是否为重复内容（简化版）
    def is_duplicate_content?(content)
      # 这里可以实现更复杂的重复内容检测算法
      # 比如计算文本指纹、与历史记录对比等

      # 简单的重复检测：检查是否有大量重复字符
      max_consecutive_chars = content.scan(/(.)\1{5,}/).length
      return true if max_consecutive_chars > 0

      # 检查是否大部分内容都是标点符号
      punctuation_ratio = content.count('.,!?;:，。！？；：').to_f / content.length
      return true if punctuation_ratio > 0.3

      false
    end

    # 检查是否需要举报
    def should_report_content?(content, check_in = nil)
      compliance = check_compliance(content)

      # 包含敏感词的建议自动举报
      if compliance[:issues].any? { |issue| issue[:type] == 'sensitive_words' }
        return {
          should_report: true,
          reason: :sensitive_words,
          auto_report: true,
          detected_words: compliance[:issues].find { |i| i[:type] == 'sensitive_words' }&.dig(:detected_words) || []
        }
      end

      # 质量分数过低的建议举报
      if compliance[:score] < 20
        return {
          should_report: true,
          reason: :inappropriate_content,
          auto_report: false,
          quality_score: compliance[:score]
        }
      end

      { should_report: false }
    end

    # 生成举报建议
    def generate_report_suggestion(content, check_in = nil)
      analysis = should_report_content?(content, check_in)

      if analysis[:should_report]
        suggestion = case analysis[:reason]
                    when :sensitive_words
                      {
                        reason: :sensitive_words,
                        message: "内容包含敏感词：#{analysis[:detected_words].join(', ')}",
                        auto_report: analysis[:auto_report],
                        priority: 'high'
                      }
                    when :inappropriate_content
                      {
                        reason: :inappropriate_content,
                        message: "内容质量过低，可能包含不当内容",
                        auto_report: false,
                        priority: 'medium'
                      }
                    else
                      {
                        reason: :other,
                        message: "内容可能需要人工审核",
                        auto_report: false,
                        priority: 'low'
                      }
                    end
      else
        suggestion = {
          reason: nil,
          message: "内容正常，无需举报",
          auto_report: false,
          priority: 'low'
        }
      end

      suggestion.merge(
        compliance: check_compliance(content),
        sensitive_words: find_sensitive_words(content),
        quality_score: calculate_quality_score(content)
      )
    end

    # 检查用户举报权限
    def can_report_content?(user, check_in)
      # 不能举报自己的内容
      return false if user == check_in.user

      # 检查是否已经举报过
      existing_report = ContentReport.find_by(user: user, check_in: check_in)
      return false if existing_report

      true
    end

    # 预处理举报内容
    def preprocess_report_content(content)
      # 清理和预处理举报内容
      sanitized = sanitize_content(content)
      # 简单的截断实现
      if sanitized.length > 1000
        truncated = sanitized[0, 997] + "..."
      else
        truncated = sanitized
      end
      truncated.strip
    end
  end
end