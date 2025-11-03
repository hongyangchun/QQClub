class CreateFlowerQuotas < ActiveRecord::Migration[8.0]
  def change
    create_table :flower_quotas do |t|
      t.references :user, null: false, foreign_key: true, comment: '用户'
      t.references :reading_event, null: false, foreign_key: true, comment: '共读活动'

      t.integer :used_flowers, default: 0, null: false, comment: '已使用的小红花数量'
      t.integer :max_flowers, default: 3, null: false, comment: '最大可赠送小红花数量'

      t.timestamps
    end

    # 添加唯一索引 - 每个用户在每个活动只能有一条记录
    add_index :flower_quotas, [:user_id, :reading_event_id], unique: true, name: 'index_flower_quotas_unique'
    # user_id 和 reading_event_id 的索引已由 references 自动创建
  end
end