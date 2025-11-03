class CreateUserActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :user_activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action_type, null: false, index: true
      t.json :details, default: {}, null: false
      t.string :ip_address
      t.string :user_agent
      t.string :session_id

      t.timestamps
    end

    # 添加复合索引优化查询性能
    add_index :user_activities, [:user_id, :created_at]
    add_index :user_activities, [:action_type, :created_at]
    add_index :user_activities, [:user_id, :action_type, :created_at]
    add_index :user_activities, :created_at, order: { created_at: :desc }
  end
end