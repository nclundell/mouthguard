class CreateTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :teams do |t|
      t.integer :cfbd_id
      t.string :school
      t.string :mascot
      t.string :abbreviation
      t.json :alternate_names
      t.string :conference
      t.string :color
      t.string :alternate_color
      t.json :logos

      t.timestamps
    end
  end
end
