class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.references :notifiable, polymorphic: true, null: false
      t.string :notification_type, null: false
      t.string :title, null: false
      t.text :content, null: false
      t.boolean :read, default: false, null: false
      t.datetime :read_at

      t.timestamps
    end

    # 添加索引（如果不存在的话）
    add_index :notifications, :recipient_id unless index_exists?(:notifications, :recipient_id)
    add_index :notifications, :actor_id unless index_exists?(:notifications, :actor_id)
    add_index :notifications, [:notifiable_type, :notifiable_id], name: 'index_notifications_on_notifiable' unless index_exists?(:notifications, [:notifiable_type, :notifiable_id])
    add_index :notifications, :notification_type unless index_exists?(:notifications, :notification_type)
    add_index :notifications, :read unless index_exists?(:notifications, :read)
    add_index :notifications, :created_at unless index_exists?(:notifications, :created_at)
  end
end
