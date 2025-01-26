class CreateLegends < ActiveRecord::Migration[8.0]
  def change
    create_table :legends do |t|
      t.integer :season
      t.string :name
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
