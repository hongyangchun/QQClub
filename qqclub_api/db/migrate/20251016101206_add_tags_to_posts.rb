class AddTagsToPosts < ActiveRecord::Migration[8.0]
  def change
    add_column :posts, :tags, :json
  end
end
