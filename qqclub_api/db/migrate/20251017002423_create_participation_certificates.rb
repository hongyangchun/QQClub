class CreateParticipationCertificates < ActiveRecord::Migration[8.0]
  def change
    create_table :participation_certificates do |t|
      t.references :reading_event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :certificate_type, null: false
      t.string :certificate_number, null: false
      t.datetime :issued_at, null: false
      t.text :achievement_data
      t.string :certificate_url
      t.boolean :is_public, default: true, null: false

      t.timestamps
    end

    # 添加索引
    add_index :participation_certificates, :certificate_number, unique: true
    add_index :participation_certificates, :certificate_type
    add_index :participation_certificates, :issued_at
    add_index :participation_certificates, :is_public
  end
end
