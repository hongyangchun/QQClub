class CreateContentReports < ActiveRecord::Migration[8.0]
  def change
    create_table :content_reports do |t|
      t.references :user, null: false, foreign_key: true, comment: '举报人'
      t.references :check_in, null: false, foreign_key: true, comment: '被举报的打卡'
      t.references :admin, foreign_key: { to_table: :users }, comment: '处理管理员'

      t.string :reason, null: false, default: 'other', comment: '举报原因'
      t.text :description, comment: '举报描述'
      t.string :status, null: false, default: 'pending', comment: '处理状态'
      t.text :admin_notes, comment: '管理员备注'
      t.datetime :reviewed_at, comment: '处理时间'

      t.timestamps
    end

    # 添加索引
    add_index :content_reports, :status
    add_index :content_reports, :reason
    add_index :content_reports, :created_at
    add_index :content_reports, [:user_id, :check_in_id], unique: true, name: 'index_content_reports_unique_reporting'
  end
end