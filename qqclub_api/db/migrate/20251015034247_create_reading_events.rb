class CreateReadingEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :reading_events do |t|
      t.string :title, null: false
      t.string :book_name, null: false
      t.string :book_cover_url
      t.text :description
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :max_participants, default: 30
      t.decimal :enrollment_fee, precision: 8, scale: 2, default: 100.0
      t.integer :status, default: 0
      t.references :leader, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :reading_events, :status
    add_index :reading_events, :start_date
  end
end
