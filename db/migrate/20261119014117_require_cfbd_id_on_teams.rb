class RequireCfbdIdOnTeams < ActiveRecord::Migration[8.1]
  def change
    change_column_null :teams, :cfbd_id, false
    add_index :teams, :cfbd_id, unique: true
  end
end
