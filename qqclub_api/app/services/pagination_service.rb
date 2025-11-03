# frozen_string_literal: true

# 分页服务
# 提供多种分页策略，优化大数据集的查询性能
class PaginationService
  class << self
    # 基于偏移量的传统分页
    # @param scope [ActiveRecord::Relation] 查询范围
    # @param page [Integer] 页码（从1开始）
    # @param per_page [Integer] 每页记录数
    # @param options [Hash] 额外选项
    # @return [Hash] 分页结果
    def paginate_by_offset(scope, page: 1, per_page: 20, options = {})
      page = [page.to_i, 1].max
      per_page = [[per_page.to_i, 1].max, 100].min # 限制最大每页100条

      total_count = QueryOptimizationService.optimized_count_query(
        scope,
        options[:cache_key] ? "count_#{options[:cache_key]}" : nil,
        options[:cache_ttl] || 5.minutes
      )

      total_pages = (total_count.to_f / per_page).ceil
      offset = (page - 1) * per_page

      records = scope.limit(per_page).offset(offset)
      records = QueryOptimizationService.preload_associations(records, options[:includes]) if options[:includes]

      {
        records: records,
        pagination: {
          current_page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: total_pages,
          has_next_page: page < total_pages,
          has_prev_page: page > 1,
          next_page: page < total_pages ? page + 1 : nil,
          prev_page: page > 1 ? page - 1 : nil
        }
      }
    end

    # 基于游标的分页（性能更好，适合大数据集）
    # @param scope [ActiveRecord::Relation] 查询范围
    # @param cursor [String] 游标位置
    # @param limit [Integer] 每页记录数
    # @param options [Hash] 额外选项
    # @return [Hash] 分页结果
    def paginate_by_cursor(scope, cursor: nil, limit: 20, options = {})
      limit = [[limit.to_i, 1].max, 100].min
      order_column = options[:order_column] || 'created_at'
      order_direction = options[:order_direction] || 'desc'

      # 构建查询
      query = scope.limit(limit + 1) # 多查询一条来判断是否还有下一页

      # 添加游标条件
      if cursor
        operator = order_direction == 'desc' ? '<' : '>'
        query = query.where("#{order_column} #{operator} ?", decode_cursor(cursor))
      end

      # 排序
      query = query.order("#{order_column} #{order_direction}")

      # 预加载关联
      if options[:includes]
        records = QueryOptimizationService.preload_associations(query, options[:includes])
      else
        records = query.to_a
      end

      # 判断是否还有下一页
      has_next = records.length > limit
      records = records.first(limit) if has_next

      # 生成下一页游标
      next_cursor = nil
      if has_next && records.any?
        last_record = records.last
        next_cursor = encode_cursor(last_record.send(order_column))
      end

      {
        records: records,
        pagination: {
          next_cursor: next_cursor,
          has_next_page: has_next,
          limit: limit,
          order_column: order_column,
          order_direction: order_direction
        }
      }
    end

    # 搜索分页（结合搜索和分页）
    # @param scope [ActiveRecord::Relation] 查询范围
    # @param search_term [String] 搜索关键词
    # @param search_fields [Array] 搜索字段
    # @param pagination_options [Hash] 分页选项
    # @return [Hash] 搜索分页结果
    def search_and_paginate(scope, search_term: nil, search_fields: [], pagination_options: {})
      # 应用搜索条件
      if search_term.present? && search_fields.any?
        search_conditions = search_fields.map do |field|
          "#{field} ILIKE ?"
        end.join(' OR ')

        search_values = search_fields.map { search_term }
        scope = scope.where(search_conditions, *search_values)
      end

      # 执行分页
      if pagination_options[:cursor]
        paginate_by_cursor(scope, pagination_options)
      else
        paginate_by_offset(scope, pagination_options)
      end
    end

    # 无限滚动分页（适合移动端）
    # @param scope [ActiveRecord::Relation] 查询范围
    # @param last_id [Integer] 上一页最后一条记录的ID
    # @param limit [Integer] 加载记录数
    # @param options [Hash] 额外选项
    # @return [Hash] 分页结果
    def infinite_scroll(scope, last_id: nil, limit: 20, options = {})
      limit = [[limit.to_i, 1].max, 50].min # 无限滚动通常限制更多

      query = scope.limit(limit + 1)

      # 添加ID条件
      if last_id
        if options[:order_direction] == 'asc'
          query = query.where('id > ?', last_id)
        else
          query = query.where('id < ?', last_id)
        end
      end

      # 排序
      order_direction = options[:order_direction] || 'desc'
      query = query.order("id #{order_direction}")

      # 预加载关联
      if options[:includes]
        records = QueryOptimizationService.preload_associations(query, options[:includes])
      else
        records = query.to_a
      end

      # 判断是否还有更多数据
      has_more = records.length > limit
      records = records.first(limit) if has_more

      # 下一页的最后ID
      next_last_id = nil
      if has_more && records.any?
        next_last_id = records.last.id
      end

      {
        records: records,
        pagination: {
          next_last_id: next_last_id,
          has_more: has_more,
          limit: limit
        }
      }
    end

    # 时间范围分页
    # @param scope [ActiveRecord::Relation] 查询范围
    # @param time_field [String] 时间字段名
    # @param start_time [DateTime] 开始时间
    # @param end_time [DateTime] 结束时间
    # @param pagination_options [Hash] 分页选项
    # @return [Hash] 时间范围分页结果
    def paginate_by_time_range(scope, time_field: 'created_at', start_time: nil, end_time: nil, pagination_options: {})
      query = scope

      # 应用时间范围过滤
      if start_time
        query = query.where("#{time_field} >= ?", start_time)
      end

      if end_time
        query = query.where("#{time_field} <= ?", end_time)
      end

      # 按时间字段排序
      query = query.order("#{time_field} DESC")

      # 执行分页
      if pagination_options[:cursor]
        # 基于时间的游标分页
        cursor_based_time_pagination(query, time_field, pagination_options)
      else
        # 传统分页
        paginate_by_offset(query, pagination_options)
      end
    end

    # 分组分页（按某个字段分组后分页）
    # @param scope [ActiveRecord::Relation] 查询范围
    # @param group_field [String] 分组字段
    # @param pagination_options [Hash] 分页选项
    # @return [Hash] 分组分页结果
    def paginate_by_group(scope, group_field, pagination_options = {})
      per_page = pagination_options[:per_page] || 10
      page = pagination_options[:page] || 1

      # 获取分组数据
      grouped_data = scope.group(group_field)
                         .select("#{group_field}, COUNT(*) as count")
                         .order("COUNT(*) DESC")
                         .to_a

      # 分页处理分组
      total_groups = grouped_data.length
      total_pages = (total_groups.to_f / per_page).ceil
      offset = (page - 1) * per_page

      paginated_groups = grouped_data[offset, per_page] || []

      # 获取每个分组的详细记录
      records = []
      paginated_groups.each do |group|
        group_records = scope.where(group_field => group.send(group_field))
                               .limit(pagination_options[:per_group_limit] || 5)
        records.concat(group_records)
      end

      {
        records: records,
        groups: paginated_groups,
        pagination: {
          current_page: page,
          per_page: per_page,
          total_groups: total_groups,
          total_pages: total_pages,
          has_next_page: page < total_pages,
          has_prev_page: page > 1
        }
      }
    end

    # 元数据分页（只返回分页信息，不返回具体记录）
    # @param scope [ActiveRecord::Relation] 查询范围
    # @param per_page [Integer] 每页记录数
    # @param options [Hash] 额外选项
    # @return [Hash] 分页元数据
    def pagination_metadata(scope, per_page: 20, options = {})
      total_count = QueryOptimizationService.optimized_count_query(
        scope,
        options[:cache_key] ? "metadata_#{options[:cache_key]}" : nil,
        options[:cache_ttl] || 10.minutes
      )

      total_pages = (total_count.to_f / per_page).ceil

      {
        total_count: total_count,
        total_pages: total_pages,
        per_page: per_page,
        first_page: 1,
        last_page: total_pages,
        page_range: calculate_page_range(total_pages, options[:current_page] || 1)
      }
    end

    private

    # 编码游标
    def encode_cursor(value)
      Base64.urlsafe_encode64(value.to_s)
    end

    # 解码游标
    def decode_cursor(cursor)
      Base64.urlsafe_decode64(cursor)
    rescue
      nil
    end

    # 基于时间的游标分页
    def cursor_based_time_pagination(scope, time_field, options)
      cursor = options[:cursor]
      limit = options[:limit] || 20

      query = scope.limit(limit + 1)

      if cursor
        decoded_time = decode_cursor(cursor)
        query = query.where("#{time_field} < ?", decoded_time) if decoded_time
      end

      query = query.order("#{time_field} DESC")
      records = query.to_a

      has_next = records.length > limit
      records = records.first(limit) if has_next

      next_cursor = nil
      if has_next && records.any?
        next_cursor = encode_cursor(records.last.send(time_field).iso8601)
      end

      {
        records: records,
        pagination: {
          next_cursor: next_cursor,
          has_next_page: has_next,
          limit: limit
        }
      }
    end

    # 计算页码范围（用于显示页码导航）
    def calculate_page_range(total_pages, current_page, window_size: 5)
      return [] if total_pages == 0

      start_page = [current_page - window_size / 2, 1].max
      end_page = [start_page + window_size - 1, total_pages].min
      start_page = [end_page - window_size + 1, 1].max if end_page - start_page + 1 < window_size

      (start_page..end_page).to_a
    end
  end
end