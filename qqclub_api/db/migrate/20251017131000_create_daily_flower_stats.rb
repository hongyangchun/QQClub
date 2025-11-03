class CreateDailyFlowerStats < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_flower_stats do |t|
      t.references :reading_event, null: false, foreign_key: true, comment: '共读活动'
      t.date :stats_date, null: false, comment: '统计日期'

      # 统计数据
      t.json :leaderboard_data, null: false, comment: '排行榜数据（JSON格式）'
      t.integer :total_flowers_given, default: 0, comment: '当日赠送小红花总数'
      t.integer :total_participants, default: 0, comment: '当日参与人数'
      t.integer :total_givers, default: 0, comment: '当日赠送人数'

      # 分享相关
      t.string :share_image_url, comment: '分享图片URL'
      t.string :share_text, comment: '分享文案'
      t.integer :share_count, default: 0, comment: '分享次数'

      # 元数据
      t.datetime :generated_at, null: false, comment: '生成时间'
      t.string :generated_by, comment: '生成者（系统自动或手动）'

      t.timestamps
    end

    # 添加索引
    add_index :daily_flower_stats, [:reading_event_id, :stats_date], unique: true, name: 'index_daily_flower_stats_unique'
    add_index :daily_flower_stats, :stats_date
    add_index :daily_flower_stats, :generated_at
  end
end