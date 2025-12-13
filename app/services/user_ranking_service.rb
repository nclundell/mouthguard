class UserRankingService
  def self.rank_users(users = User.includes(picks: :game))
    users.each { |user| user.points = user.points_for_season }

    sorted = users.sort_by { |user| [-user.points, user.name.downcase] }

    prev_points = nil
    prev_rank = 0
    sorted.each_with_index do |user, i|
      if prev_points == user.points
        user.rank = prev_rank
      else
        user.rank = i + 1
        prev_rank = user.rank
        prev_points = user.points
      end
    end

    sorted
  end

  def self.rank_for(user)
    ranked_users = rank_users
    found = ranked_users.find { |u| u.id == user.id }
    found&.rank
  end

  def self.leaders
    ranked_users = rank_users
    ranked_users.select { |user| user.rank == 1 }
  end
end
