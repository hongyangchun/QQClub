class CreateLikes < ActiveRecord::Migration[8.0]
  def change
    create_table :likes do |t|
      t.string :target_type
      t.integer :target_id
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
