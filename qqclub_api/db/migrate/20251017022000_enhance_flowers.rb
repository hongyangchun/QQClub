class EnhanceFlowers < ActiveRecord::Migration[8.0]
  def change
    add_column :flowers, :amount, :integer, default: 1, comment: '小红花数量'
    add_column :flowers, :flower_type, :string, default: 'regular', comment: '小红花类型'
    add_column :flowers, :is_anonymous, :boolean, default: false, comment: '是否匿名赠送'
    add_column :flowers, :created_at_for_batch, :datetime, comment: '批量创建时间'

    # 添加索引
    add_index :flowers, :flower_type
    add_index :flowers, :is_anonymous
    add_index :flowers, :created_at_for_batch
  end
end