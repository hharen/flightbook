class ProfilesController < ApplicationController
  def show
    @user = current_user
    @sessions_count = @user.flying_sessions.count
    @total_flight_time = @user.total_flight_time
    @total_flights = @user.flying_sessions.sum(:flights)
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(profile_params)
      redirect_to profile_path, notice: t("flash.profiles.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    permitted = params.require(:user).permit(:name, :email, :password, :password_confirmation)
    permitted.delete(:password) if permitted[:password].blank?
    permitted.delete(:password_confirmation) if permitted[:password_confirmation].blank?
    permitted
  end
end
