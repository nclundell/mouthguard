class CreateComments < ActiveRecord::Migration[8.0]
  def change
    create_table :comments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :game, foreign_key: true
      t.integer :season, null: false
      t.string :content

      t.timestamps
    end
  end
end
