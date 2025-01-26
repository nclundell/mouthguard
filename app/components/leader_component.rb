# frozen_string_literal: true

class LeaderComponent < ViewComponent::Base
  def initialize(user:, extra_classes: "")
    @user = user
    @extra_classes = extra_classes
  end
end
