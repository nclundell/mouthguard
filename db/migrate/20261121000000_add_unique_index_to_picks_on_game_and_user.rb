class AddUniqueIndexToPicksOnGameAndUser < ActiveRecord::Migration[8.1]
  def change
    add_index :picks, [ :game_id, :user_id ], unique: true, name: "index_picks_on_game_id_and_user_id"
  end
end
