class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :wx_openid, null: false
      t.string :wx_unionid
      t.string :nickname
      t.string :avatar_url
      t.string :phone

      t.timestamps
    end

    add_index :users, :wx_openid, unique: true
    add_index :users, :wx_unionid, unique: true
  end
end
