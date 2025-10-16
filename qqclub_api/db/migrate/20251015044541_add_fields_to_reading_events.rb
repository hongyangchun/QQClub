class AddFieldsToReadingEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :reading_events, :leader_assignment_type, :string
    add_column :reading_events, :approval_status, :integer
    add_reference :reading_events, :approved_by, foreign_key: { to_table: :users }
    add_column :reading_events, :approved_at, :datetime
  end
end
