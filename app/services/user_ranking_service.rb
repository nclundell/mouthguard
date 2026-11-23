class UserRankingService
  Row = Data.define(:user, :name, :points, :rank, :can_win)

  def self.rank_users(season: Current.season)
    users = User.includes(avatar_attachment: :blob).to_a
    points = Pick.correct.joins(:game).where(games: { season: season }).group(:user_id).count
    open_game_ids = Game.where(season: season).open
                        .where(completed: [ false, nil ])
                        .where("status IS NULL OR status != ?", "completed").pluck(:id)
    picks = Pick.where(game_id: open_game_ids).pluck(:user_id, :game_id, :team_id)
                .to_h { |user_id, game_id, team_id| [[user_id, game_id], team_id] }

    sorted = users.sort_by { |user| [-points.fetch(user.id, 0), name_for(user).downcase, user.id] }
    leader = sorted.first
    leader_points = leader && points.fetch(leader.id, 0)
    previous_points = nil
    rank = 0

    sorted.each_with_index.map do |user, index|
      score = points.fetch(user.id, 0)
      rank = index + 1 unless score == previous_points
      previous_points = score
      differences = open_game_ids.count do |game_id|
        team_id = picks[[user.id, game_id]]
        team_id && team_id != picks[[leader.id, game_id]]
      end
      Row.new(user: user, name: name_for(user), points: score, rank: rank,
              can_win: rank == 1 || score + differences > leader_points)
    end
  end

  def self.name_for(user)
    user.name.presence || "Player"
  end
  private_class_method :name_for
end
