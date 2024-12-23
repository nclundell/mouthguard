class CreateGameComments < ActiveRecord::Migration[8.0]
  def change
    create_table :game_comments do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :comment

      t.timestamps
    end
  end
end
