class CreateFlowerCertificates < ActiveRecord::Migration[8.0]
  def change
    create_table :flower_certificates do |t|
      t.references :user, null: false, foreign_key: true, comment: '获奖用户'
      t.references :reading_event, null: false, foreign_key: true, comment: '共读活动'

      t.integer :rank, null: false, comment: '排名（1,2,3）'
      t.integer :total_flowers, null: false, comment: '获得的小红花总数'
      t.string :certificate_id, null: false, comment: '证书唯一编号'

      t.timestamps
    end

    # 添加索引
    add_index :flower_certificates, :certificate_id, unique: true
    add_index :flower_certificates, [:reading_event_id, :rank], unique: true, name: 'index_flower_certificates_unique_rank'
    # user_id 和 reading_event_id 的索引已由 references 自动创建
  end
end