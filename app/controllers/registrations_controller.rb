class RegistrationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create]

  def new
    redirect_to root_path if current_user
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Welcome, #{@user.name}! Your account has been created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
