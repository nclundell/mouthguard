class CreatePicks < ActiveRecord::Migration[8.0]
  def change
    create_table :picks do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :team, null: true, foreign_key: true

      t.timestamps
    end
  end
end
