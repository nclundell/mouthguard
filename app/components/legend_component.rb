# frozen_string_literal: true

class LegendComponent < ViewComponent::Base
  def initialize(legend:, extra_classes: "")
    @legend = legend
    @extra_classes = extra_classes
  end
end
