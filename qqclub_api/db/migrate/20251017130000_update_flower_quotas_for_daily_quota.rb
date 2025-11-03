class UpdateFlowerQuotasForDailyQuota < ActiveRecord::Migration[8.0]
  def change
    # 添加配额日期字段
    add_column :flower_quotas, :quota_date, :date, null: false, comment: '配额日期'

    # 添加日期类型的索引
    add_index :flower_quotas, :quota_date

    # 创建新的复合唯一索引 (用户ID + 活动ID + 配额日期)
    add_index :flower_quotas, [:user_id, :reading_event_id, :quota_date],
              unique: true,
              name: 'index_flower_quotas_daily_unique'

    # 暂时保留旧的索引，等数据迁移完成后再删除
    # remove_index :flower_quotas, name: 'index_flower_quotas_unique'

    # 添加统计相关字段
    add_column :flower_quotas, :last_given_at, :datetime, comment: '最后赠送时间'
    add_column :flower_quotas, :give_count_today, :integer, default: 0, comment: '今日赠送次数'
  end
end