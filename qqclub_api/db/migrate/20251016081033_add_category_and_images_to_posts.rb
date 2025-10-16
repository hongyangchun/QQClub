class AddCategoryAndImagesToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :category, :string
    add_column :posts, :images, :json
  end
end
