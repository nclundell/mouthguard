# frozen_string_literal: true

class Form::PickComponent < ViewComponent::Base
  def initialize(pick:)
    @pick = pick
  end
end
