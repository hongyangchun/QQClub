class AddApprovalWorkflowFieldsToReadingEvents < ActiveRecord::Migration[7.0]
  def change
    # 审批流程相关字段
    add_column :reading_events, :submitted_for_approval_at, :datetime
    add_column :reading_events, :approval_reason, :text
    add_column :reading_events, :approval_notes, :text
    add_column :reading_events, :rejection_reason, :text
    add_column :reading_events, :escalation_reason, :text
    add_column :reading_events, :escalated_at, :datetime
    add_column :reading_events, :escalated_by_user_id, :bigint

    # 添加索引
    add_index :reading_events, :submitted_for_approval_at
    add_index :reading_events, :escalated_at
    add_index :reading_events, :escalated_by_user_id

    # 添加外键约束
    add_foreign_key :reading_events, :users, column: :escalated_by_user_id
  end
end