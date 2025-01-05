class DropTableGameComments < ActiveRecord::Migration[8.0]
  def change
    drop_table :game_comments
  end
end
