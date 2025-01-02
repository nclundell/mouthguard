class AddPlayoffFlagToGames < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :playoff, :boolean
  end
end
