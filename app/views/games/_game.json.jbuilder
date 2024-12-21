json.extract! game, :id, :cfbd_id, :season, :start, :completed, :attendance, :venue_id_id, :home_id_id, :home_points, :home_line_scores, :away_id_id, :away_points, :away_line_scores, :highlights, :notes, :created_at, :updated_at
json.url game_url(game, format: :json)
