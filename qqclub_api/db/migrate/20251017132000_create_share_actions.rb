class CreateShareActions < ActiveRecord::Migration[8.0]
  def change
    create_table :share_actions do |t|
      t.string :share_type, null: false, comment: '分享类型（daily_leaderboard, final_leaderboard, certificate等）'
      t.integer :resource_id, null: false, comment: '资源ID'
      t.string :platform, null: false, comment: '分享平台（wechat, weibo等）'
      t.integer :user_id, comment: '用户ID'
      t.string :ip_address, comment: 'IP地址'
      t.text :user_agent, comment: '用户代理'
      t.datetime :shared_at, null: false, comment: '分享时间'

      t.timestamps
    end

    # 添加索引
    add_index :share_actions, [:share_type, :resource_id]
    add_index :share_actions, :platform
    add_index :share_actions, :user_id
    add_index :share_actions, :shared_at
    add_index :share_actions, [:share_type, :platform, :shared_at]
  end
end