class Legend < ApplicationRecord
  belongs_to :user, optional: true

  def self.detect_user(full_name)
    split = full_name.split
    User.find_by(
      first_name: split.first,
      last_name: split.last
    )
  end

  def self.hall_of_fame
    hof = ActiveRecord::Base.connection.execute(Legend.hall_of_fame_query)
    hof.each do |l|
      l["seasons"] = l["seasons"].split(",")
    end
  end

  private

  def self.hall_of_fame_query
    <<-SQL
      select count(*) as total_wins, name, group_concat(season) as seasons, user_id
      from legends
      group by name
      order by total_wins desc, name
    SQL
  end
end
