class DashboardController < ApplicationController
  allow_unauthenticated_access

  def index
    @games = Game.all.select { |g| g.today? || g.is_live? }
  end
end
