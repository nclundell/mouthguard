class LiveGamesJob < ApplicationJob
  FIELDS = {
    tv: :tv, status: :status, period: :period, clock: :clock,
    situation: :situation, possession: :possession, lastPlay: :last_play
  }.freeze
  TEAM_FIELDS = { points: :points, lineScores: :line_scores }.freeze

  def perform
    return unless Game.live.exists?

    Cfbd::Rest.scoreboard.each do |source|
      game = Game.live.find_by(cfbd_id: source.id)
      next unless game

      attributes = fields_from(source, FIELDS)
      attributes[:completed] = true if source.status == "completed"
      %i[home away].each do |side|
        team = source.public_send("#{side}Team")
        next unless team

        fields_from(team, TEAM_FIELDS).each do |field, value|
          attributes[:"#{side}_#{field}"] = value
        end
      end

      game.update!(attributes)
    end
  end

  private

  def fields_from(source, fields)
    fields.each_with_object({}) do |(remote, local), attributes|
      attributes[local] = source.public_send(remote) if source.to_h.key?(remote)
    end
  end
end
