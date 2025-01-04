class AddSeasonToPicks < ActiveRecord::Migration[8.0]
  def change
    add_column :picks, :season, :integer
  end
end
