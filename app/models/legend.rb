class Legend < ApplicationRecord
  belongs_to :user, optional: true

  def self.hall_of_fame
    includes(user: { avatar_attachment: :blob }).to_a.group_by(&:name).map do |name, wins|
      {
        name: name,
        total_wins: wins.size,
        seasons: wins.filter_map(&:season).sort,
        user: wins.find { |win| win.user }&.user
      }
    end.sort_by { |winner| [ -winner[:total_wins], winner[:name].to_s ] }
  end
end
