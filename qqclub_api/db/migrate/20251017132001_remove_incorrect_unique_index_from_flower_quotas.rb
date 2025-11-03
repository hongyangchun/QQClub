# frozen_string_literal: true

class RemoveIncorrectUniqueIndexFromFlowerQuotas < ActiveRecord::Migration[8.0]
  def change
    # 移除错误的唯一索引，这个索引会阻止同一用户在不同日期为同一活动创建配额记录
    # 正确的唯一索引应该是 [user_id, reading_event_id, quota_date]
    remove_index :flower_quotas, name: :index_flower_quotas_unique, if_exists: true
  end
end
