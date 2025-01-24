# frozen_string_literal: true

class PickComponent < ViewComponent::Base
  def initialize(pick:)
    @pick = pick
  end
end
