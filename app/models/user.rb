include ApplicationHelper

class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :game_comments
  has_many :picks

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  accepts_nested_attributes_for :picks

  def name
    return display_name unless display_name.blank?
    return "#{first_name} #{last_name}" unless first_name.blank? || last_name.blank?
    return first_name unless first_name.blank?

    email_address
  end

  def picks_correct
    picks.select { |p| p.game.season == current_season && p.game.winner == p.team }.count
  end
end
