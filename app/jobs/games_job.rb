class GamesJob < ApplicationJob
  def perform
    games = Cfbd::Rest.games(year: Current.season, seasonType: "postseason", classification: "fbs")

    Game.transaction do
      games.each do |source|
        notes = source.notes.to_s.partition("Presented").first.partition(" - ").first.strip
        notes = notes.gsub("College Football Playoff", "CFP")

        game = Game.find_or_initialize_by(cfbd_id: source.id)
        game.assign_attributes(
          season: source.season,
          start: source.startDate,
          completed: source.completed,
          attendance: source.attendance,
          venue: Venue.find_by(cfbd_id: source.venueId),
          home: team_for(source.homeId, "home"),
          away: team_for(source.awayId, "away"),
          home_points: source.homePoints,
          away_points: source.awayPoints,
          home_line_scores: source.homeLineScores,
          away_line_scores: source.awayLineScores,
          highlights: source.highlights,
          notes: notes,
          playoff: source.playoff.present?
        )
        game.save!
      end
    end
  end

  private

  def team_for(id, side)
    return if id.blank?

    Team.find_by(cfbd_id: id) ||
      raise(ActiveRecord::RecordNotFound, "No local #{side} Team for CFBD ID #{id}")
  end
end
