class CreateEnrollments < ActiveRecord::Migration[8.0]
  def change
    create_table :enrollments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :reading_event, null: false, foreign_key: true
      t.integer :payment_status, default: 0
      t.integer :role, default: 0
      t.integer :leading_count, default: 0
      t.decimal :paid_amount, precision: 8, scale: 2
      t.decimal :refund_amount, precision: 8, scale: 2

      t.timestamps
    end

    add_index :enrollments, [:user_id, :reading_event_id], unique: true
  end
end
