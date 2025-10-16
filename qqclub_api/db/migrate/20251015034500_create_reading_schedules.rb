class CreateReadingSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :reading_schedules do |t|
      t.references :reading_event, null: false, foreign_key: true
      t.integer :day_number, null: false
      t.date :date, null: false
      t.string :reading_progress, null: false
      t.references :daily_leader, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :reading_schedules, [:reading_event_id, :day_number], unique: true
    add_index :reading_schedules, :date
  end
end
