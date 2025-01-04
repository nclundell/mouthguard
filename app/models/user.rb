include ApplicationHelper

class User < ApplicationRecord
  has_secure_password

  after_create :generate_picks

  has_many :sessions, dependent: :destroy
  has_many :game_comments
  has_many :picks, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  accepts_nested_attributes_for :picks

  def generate_picks
    Rails.logger.info("Generating picks for: #{email_address}")

    Game.where(season: current_season).each do |g|
      Pick.find_or_create_by(game: g, user: self, season: game.season)
    end
  end

  def name
    return display_name unless display_name.blank?
    return "#{first_name} #{last_name}" unless first_name.blank? || last_name.blank?
    return first_name unless first_name.blank?

    email_address
  end

  def picks_correct
    picks.select { |p| p.game.season == current_season && p.game.winner == p.team && p.team.present? }.count
  end
end
