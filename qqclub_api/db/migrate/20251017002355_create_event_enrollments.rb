class CreateEventEnrollments < ActiveRecord::Migration[8.0]
  def change
    create_table :event_enrollments do |t|
      t.references :reading_event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :enrollment_type, default: 'participant', null: false
      t.string :status, default: 'enrolled', null: false
      t.datetime :enrollment_date, null: false
      t.decimal :completion_rate, precision: 5, scale: 2, default: 0.00, null: false
      t.integer :check_ins_count, default: 0, null: false
      t.integer :leader_days_count, default: 0, null: false
      t.integer :flowers_received_count, default: 0, null: false
      t.decimal :fee_paid_amount, precision: 10, scale: 2, default: 0.00, null: false
      t.decimal :fee_refund_amount, precision: 10, scale: 2, default: 0.00, null: false
      t.string :refund_status, default: 'pending', null: false

      t.timestamps
    end

    # 添加唯一约束：一个用户只能报名一次同一个活动
    add_index :event_enrollments, [:reading_event_id, :user_id], unique: true
    add_index :event_enrollments, :status
    add_index :event_enrollments, :enrollment_type
    add_index :event_enrollments, :enrollment_date
  end
end
