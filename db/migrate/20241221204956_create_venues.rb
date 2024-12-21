class CreateVenues < ActiveRecord::Migration[8.0]
  def change
    create_table :venues do |t|
      t.integer :cfbd_id
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
  end
end
