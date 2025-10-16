class CreateCheckIns < ActiveRecord::Migration[8.0]
  def change
    create_table :check_ins do |t|
      t.references :user, null: false, foreign_key: true
      t.references :reading_schedule, null: false, foreign_key: true
      t.references :enrollment, null: false, foreign_key: true
      t.text :content, null: false
      t.integer :word_count, default: 0
      t.integer :status, default: 0
      t.datetime :submitted_at

      t.timestamps
    end

    add_index :check_ins, [:user_id, :reading_schedule_id], unique: true
  end
end
