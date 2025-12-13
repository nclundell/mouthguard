class AddCorrectToPicks < ActiveRecord::Migration[8.0]
  def change
    add_column :picks, :correct, :boolean
  end
end
