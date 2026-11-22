class AddCorrectToPicks < ActiveRecord::Migration[8.1]
  def up
    add_column :picks, :correct, :boolean
  end

  def down
    remove_column :picks, :correct
  end
end
