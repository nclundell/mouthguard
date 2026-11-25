class AddSeasonToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :season, :integer
  end
end
