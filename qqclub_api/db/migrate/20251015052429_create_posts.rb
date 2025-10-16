class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.text :content, null: false
      t.references :user, null: false, foreign_key: true
      t.boolean :pinned, default: false
      t.boolean :hidden, default: false

      t.timestamps
    end
  end
end
