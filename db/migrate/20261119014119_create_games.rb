class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.integer :cfbd_id, null: false
      t.integer :season
      t.datetime :start
      t.boolean :completed
      t.integer :attendance
      t.references :venue, foreign_key: true
      t.references :home, foreign_key: { to_table: :teams }
      t.integer :home_points
      t.json :home_line_scores
      t.references :away, foreign_key: { to_table: :teams }
      t.integer :away_points
      t.json :away_line_scores
      t.string :highlights
      t.string :notes
      t.string :tv
      t.string :status
      t.string :period
      t.string :clock
      t.string :situation
      t.string :possession
      t.string :last_play
      t.boolean :playoff

      t.timestamps
    end

    add_index :games, :cfbd_id, unique: true
  end
end
