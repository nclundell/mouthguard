class UsersController < ApplicationController
  def show
    @user = User.find(params[:id])

    redirect_to Current.user if Current.user != @user
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])
    if @user.update(user_params)
      redirect_to @user, notice: "Account updated successfully!"
    else
      render :edit
    end
  end

  private

  def user_params
    params.require(:user).permit(:avatar, :first_name, :last_name, :display_name, :email_address)
  end
end
