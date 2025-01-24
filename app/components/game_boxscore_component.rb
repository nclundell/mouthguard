# frozen_string_literal: true

class GameBoxscoreComponent < ViewComponent::Base
  def initialize(game:)
    @game = game
  end
end
