class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.integer :cfbd_id
      t.integer :season
      t.datetime :start
      t.boolean :completed
      t.integer :attendance
      t.references :venue, foreign_key: { to_table: "venues" }
      t.references :home, foreign_key: { to_table: "teams" }
      t.integer :home_points
      t.json :home_line_scores
      t.references :away, foreign_key: { to_table: "teams" }
      t.integer :away_points
      t.json :away_line_scores
      t.string :highlights
      t.string :notes

      t.timestamps
    end
  end
end
