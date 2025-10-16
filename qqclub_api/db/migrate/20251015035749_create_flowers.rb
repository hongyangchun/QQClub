class CreateFlowers < ActiveRecord::Migration[8.0]
  def change
    create_table :flowers do |t|
      t.references :check_in, null: false, foreign_key: true, index: { unique: true }
      t.references :giver, null: false, foreign_key: { to_table: :users }
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :reading_schedule, null: false, foreign_key: true
      t.text :comment

      t.timestamps
    end

    add_index :flowers, [:reading_schedule_id, :giver_id]
  end
end
