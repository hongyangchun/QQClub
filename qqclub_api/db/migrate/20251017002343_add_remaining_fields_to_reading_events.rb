class AddRemainingFieldsToReadingEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :reading_events, :activity_mode, :string, default: 'note_checkin', null: false
    add_column :reading_events, :weekend_rest, :boolean, default: false, null: false
    add_column :reading_events, :completion_standard, :integer, default: 80, null: false
    add_column :reading_events, :fee_type, :string, default: 'free', null: false
    add_column :reading_events, :fee_amount, :decimal, precision: 10, scale: 2, default: 0.00, null: false
    add_column :reading_events, :leader_reward_percentage, :decimal, precision: 5, scale: 2, default: 20.00, null: false
    add_column :reading_events, :min_participants, :integer, default: 10, null: false
    add_column :reading_events, :enrollment_deadline, :datetime

    # 添加索引
    add_index :reading_events, :activity_mode
    add_index :reading_events, :fee_type
    add_index :reading_events, :enrollment_deadline
  end
end
