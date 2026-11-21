class ProfilesController < ApplicationController
  def show
    @user = Current.user
  end

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user
    @avatar = @user.avatar.blob if @user.avatar.attached?
    attributes = profile_params
    @user.assign_attributes(attributes)
    @user.avatar = nil if params.dig(:user, :remove_avatar) == "1" && attributes[:avatar].blank?
    changing_password = password_params[:password].present?

    if changing_password
      unless @user.authenticate(password_params[:current_password])
        @user.errors.add(:current_password, "is incorrect or missing")
        return render :edit, status: :unprocessable_entity
      end

      @user.assign_attributes(password_params.slice(:password, :password_confirmation))
      @user.errors.add(:password_confirmation, :blank) if password_params[:password_confirmation].blank?
    end

    if @user.errors.empty? && @user.save
      @user.sessions.where.not(id: Current.session.id).destroy_all if changing_password
      redirect_to profile_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def profile_params
      params.require(:user).permit(:email_address, :first_name, :last_name, :display_name, :avatar)
    end

    def password_params
      params.require(:user).permit(:current_password, :password, :password_confirmation)
    end
end
