# frozen_string_literal: true

# OptimizedPaginationService - 高性能分页服务
# 使用cursor-based pagination避免OFFSET性能问题
class OptimizedPaginationService < ApplicationService
  include ServiceInterface

  attr_reader :relation, :page, :per_page, :cursor, :order_field, :order_direction

  def initialize(relation:, page: nil, per_page: 20, cursor: nil, order_field: :created_at, order_direction: :desc)
    super()
    @relation = relation
    @page = page
    @per_page = per_page
    @cursor = cursor
    @order_field = order_field
    @order_direction = order_direction
  end

  def call
    handle_errors do
      validate_parameters
      paginate
    end
    self
  end

  # 类方法：快速分页
  def self.paginate(relation, page: 1, per_page: 20, cursor: nil, order_field: :created_at, order_direction: :desc)
    new(
      relation: relation,
      page: page,
      per_page: per_page,
      cursor: cursor,
      order_field: order_field,
      order_direction: order_direction
    ).call
  end

  # 类方法：cursor-based分页（适用于无限滚动）
  def self.cursor_paginate(relation, cursor: nil, per_page: 20, order_field: :created_at, order_direction: :desc)
    new(
      relation: relation,
      cursor: cursor,
      per_page: per_page,
      order_field: order_field,
      order_direction: order_direction
    ).call
  end

  def data
    @data ||= {}
  end

  def has_next_page?
    data[:has_next_page]
  end

  def has_prev_page?
    data[:has_prev_page]
  end

  def next_cursor
    data[:next_cursor]
  end

  def prev_cursor
    data[:prev_cursor]
  end

  def total_count
    data[:total_count]
  end

  private

  def validate_parameters
    errors.add(:relation, "查询对象不能为空") if relation.blank?
    errors.add(:per_page, "每页数量必须大于0") if per_page.to_i <= 0
    errors.add(:per_page, "每页数量不能超过100") if per_page.to_i > 100

    if cursor && page
      errors.add(:base, "不能同时使用cursor和page分页")
    end

    # 验证排序字段是否存在
    if order_field.present? && !relation.column_names.include?(order_field.to_s)
      errors.add(:order_field, "无效的排序字段")
    end
  end

  def paginate
    if cursor.present?
      cursor_based_pagination
    else
      offset_based_pagination
    end
  end

  # 基于OFFSET的传统分页
  def offset_based_pagination
    page_num = [page.to_i, 1].max
    offset_value = (page_num - 1) * per_page

    # 获取总记录数（可选，用于显示分页信息）
    if should_count_total?
      total_records = relation.count
    else
      total_records = nil
    end

    # 执行分页查询
    paginated_relation = relation
                      .limit(per_page + 1)  # 多查询一条用于判断是否有下一页
                      .offset(offset_value)
                      .order(order_direction_sql)

    records = paginated_relation.to_a
    has_next = records.length > per_page
    records.pop if has_next  # 移除多查询的记录

    data.merge!({
      records: records,
      current_page: page_num,
      per_page: per_page,
      has_next_page: has_next,
      has_prev_page: page_num > 1,
      total_count: total_records,
      total_pages: total_records ? (total_records.to_f / per_page).ceil : nil
    })

    self
  end

  # 基于cursor的高性能分页
  def cursor_based_pagination
    # 解析cursor
    cursor_value = decode_cursor(cursor) if cursor

    # 构建查询条件
    query_relation = relation
    if cursor_value
      query_relation = query_relation.where(cursor_condition(cursor_value))
    end

    # 执行查询，多查询一条用于判断是否有下一页
    paginated_relation = query_relation
                          .limit(per_page + 1)
                          .order(order_direction_sql)

    records = paginated_relation.to_a
    has_next = records.length > per_page
    records.pop if has_next

    # 生成cursor信息
    next_cursor_value = records.last ? records.last[order_field] : nil
    prev_cursor_value = records.first ? records.first[order_field] : nil

    data.merge!({
      records: records,
      per_page: per_page,
      has_next_page: has_next,
      has_prev_page: cursor.present?,
      next_cursor: next_cursor_value ? encode_cursor(next_cursor_value) : nil,
      prev_cursor: prev_cursor_value ? encode_cursor(prev_cursor_value) : nil
    })

    self
  end

  def order_direction_sql
    case order_direction.to_sym
    when :asc
      "#{order_field} ASC"
    when :desc
      "#{order_field} DESC"
    else
      "#{order_field} DESC"  # 默认降序
    end
  end

  def cursor_condition(cursor_value)
    case order_direction.to_sym
    when :asc
      "#{order_field} > ?"
    when :desc
      "#{order_field} < ?"
    else
      "#{order_field} < ?"  # 默认降序
    end
  end

  def encode_cursor(value)
    # Base64编码cursor值
    Base64.urlsafe_encode64("#{value}:#{Time.current.to_i}")
  end

  def decode_cursor(encoded_cursor)
    return nil unless encoded_cursor

    begin
      decoded = Base64.urlsafe_decode64(encoded_cursor)
      decoded.split(':').first
    rescue
      nil
    end
  end

  def should_count_total?
    # 只有在第一页时才计算总数，避免性能问题
    page.to_i <= 1 && !cursor
  end
end