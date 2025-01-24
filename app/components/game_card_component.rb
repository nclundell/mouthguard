# frozen_string_literal: true

class GameCardComponent < ViewComponent::Base
  def initialize(game:)
    @game = game
  end
end
