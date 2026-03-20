class UsersController < ApplicationController
  before_action :require_admin!
  before_action :set_user, only: %i[edit update destroy]

  # GET /users
  def index
    @users = current_user.created_users
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit
  end

  # POST /users
  def create
    @user = current_user.created_users.build(user_params)

    if @user.save
      redirect_to users_path, notice: "User was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /users/1
  def update
    if @user.update(user_params)
      redirect_to users_path, notice: "User was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /users/1
  def destroy
    @user.destroy!
    redirect_to users_path, notice: "User was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = current_user.created_users.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def user_params
      permitted = params.require(:user).permit(:name, :email, :password, :password_confirmation, :admin)
      # Don't update password if blank on edit
      permitted.delete(:password) if permitted[:password].blank?
      permitted.delete(:password_confirmation) if permitted[:password_confirmation].blank?
      permitted
    end
end
