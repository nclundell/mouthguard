class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :picks, dependent: :destroy
  has_one_attached :avatar

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  validates :email_address, presence: true, uniqueness: true
  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  
  def name
    return display_name unless display_name.blank?

    [ first_name, last_name ].join(' ') || email_address
  end

  def full_picks
    picks.joins(:game)
    .merge(Game.current)
    .includes(game: [ :away, :home ])
    .order("games.start", "games.id")
  end

  def seed_picks
    Game.current.each { |game| picks.find_or_create_by(game: game) }
  end
end
