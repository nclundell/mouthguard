class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    @user.valid?
    @user.errors.add(:password_confirmation, :blank) if @user.password_confirmation.blank?

    if @user.errors.empty? && @user.save
      seed_picks_for_user
      start_new_session_for @user
      redirect_to after_authentication_url
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def seed_picks_for_user
      @user.seed_picks
    rescue StandardError => error
      Rails.logger.error("Pick seeding failed for user #{@user.id}: #{error.full_message}")
    end

    def registration_params
      params.require(:user).permit(:email_address, :display_name, :password, :password_confirmation)
    end
end
