class CreateDailyLeadings < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_leadings do |t|
      t.references :reading_schedule, null: false, foreign_key: true, index: { unique: true }
      t.references :leader, null: false, foreign_key: { to_table: :users }
      t.text :reading_suggestion, null: false
      t.text :questions, null: false

      t.timestamps
    end
  end
end
