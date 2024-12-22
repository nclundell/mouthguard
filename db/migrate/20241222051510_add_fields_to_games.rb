class AddFieldsToGames < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :tv, :string
    add_column :games, :status, :string
    add_column :games, :period, :string
    add_column :games, :clock, :string
    add_column :games, :situation, :string
    add_column :games, :possession, :string
    add_column :games, :last_play, :string
  end
end
