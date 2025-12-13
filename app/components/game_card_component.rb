# frozen_string_literal: true

class GameCardComponent < ViewComponent::Base
  def initialize(game:, title: true, extra_classes: "")
    @game = game
    @title = title
    @extra_classes = extra_classes
  end
end
