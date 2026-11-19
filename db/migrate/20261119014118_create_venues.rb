class CreateVenues < ActiveRecord::Migration[8.1]
  def change
    create_table :venues do |t|
      t.integer :cfbd_id, null: false
      t.string :name
      t.string :city
      t.string :state
      t.string :zip
      t.string :country_code
      t.string :timezone
      t.integer :capacity
      t.integer :construction_year
      t.boolean :grass
      t.boolean :dome

      t.timestamps
    end

    add_index :venues, :cfbd_id, unique: true
  end
end
