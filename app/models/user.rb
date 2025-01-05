include ApplicationHelper

class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :game_comments
  has_many :picks, dependent: :destroy

  has_one_attached :avatar

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  after_create :generate_picks

  attr_accessor :points, :rank

  accepts_nested_attributes_for :picks

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

  def picks_correct
    picks.select { |p| p.game.season == current_season && p.game.winner == p.team && p.team.present? }.count
  end

  def remaining_pick_difference(other_user)
    count = 0
    Game.to_be_played.this_season.each do |g|
      user_pick = g.picks.by_user(self).first.team
      other_pick = g.picks.by_user(other_user).first.team

      count += 1 unless user_pick == other_pick
    end

    count
  end

  def potential_pick_difference(other_user)
    return false if other_user.blank?

    played_difference = self.picks_correct - other_user.picks_correct
    played_difference - remaining_pick_difference(other_user)
  end

  def can_win?
    return true if User.leaders.include? self
    self.potential_pick_difference(User.leaders.first) > 0
  end

  def self.leaders
    User.rank.select { |user| user.rank == 1 }
  end

  def self.rank
    prev = nil
    ranked = []
    User.sort_by_picks_correct.each_with_index do |user, i|
      user.points = user.picks_correct
      if prev.present? && prev.points == user.points
        user.rank = prev.rank
      else
        user.rank = i + 1
      end
      prev = user
      ranked.append(user)
    end

    ranked
  end

  def self.sort_by_picks_correct
    all.sort_by { |user| -user.picks_correct }
  end
end
