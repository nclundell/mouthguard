include ApplicationHelper

class User < ApplicationRecord
  has_secure_password

  has_many :comments, dependent: :destroy
  has_many :picks, dependent: :destroy
  has_many :sessions, dependent: :destroy

  has_one_attached :avatar

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  after_create :generate_picks

  attr_accessor :points, :rank

  accepts_nested_attributes_for :picks

  def can_win?
    leaders = UserRankingService.leaders
    return true if leaders.include? self
    leader = leaders.first
    return false if leader.blank?

    max_possible_points = points_for_season + remaining_pick_difference(leader)

    max_possible_points > leader.points_for_season
  end

  def generate_picks
    Rails.logger.info("Generating picks for: #{email_address}")

    Game.where(season: current_season).each do |g|
      Pick.find_or_create_by(game: g, user: self, season: g.season)
    end
  end

  def name
    return display_name unless display_name.blank?
    return "#{first_name} #{last_name}" unless first_name.blank? || last_name.blank?
    return first_name unless first_name.blank?

    email_address
  end

  def points_for_season(season = current_season)
    picks.joins(:game).where(correct: true, games: { season: season }).count
  end

  def remaining_pick_difference(other_user)
    count = 0
    Game.to_be_played.this_season.each do |g|
      user_pick = g.picks.for_user(self).first.team
      other_pick = g.picks.for_user(other_user).first.team

      count += 1 unless user_pick == other_pick
    end

    count
  end
end
