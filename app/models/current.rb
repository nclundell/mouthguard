class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true

  def season
    2025 # (Date.current - 6.months).year
  end
end
