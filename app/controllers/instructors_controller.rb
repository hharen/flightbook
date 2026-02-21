class InstructorsController < ApplicationController
  before_action :set_instructor, only: %i[edit update destroy]

  # GET /instructors
  def index
    @users = User.all
    @instructors = Instructor.all

    if params.key?(:user_id)
      # User explicitly selected a filter (including "All users" which sends blank)
      @selected_user = params[:user_id].present? ? User.find(params[:user_id]) : nil
    else
      # First visit — preselect Hana
      @selected_user = User.find_by(name: "Hana")
    end

    # Build a hash of instructor stats filtered by user
    @instructor_stats = {}
    @instructors.each do |instructor|
      sessions = instructor.flying_sessions
      sessions = sessions.where(user: @selected_user) if @selected_user
      @instructor_stats[instructor.id] = {
        sessions_count: sessions.count,
        flight_time: sessions.sum(:duration).to_i
      }
    end
  end

  # GET /instructors/new
  def new
    @instructor = Instructor.new
  end

  # GET /instructors/1/edit
  def edit
  end

  # POST /instructors
  def create
    @instructor = Instructor.new(instructor_params)

    if @instructor.save
      redirect_to instructors_path, notice: "Instructor was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /instructors/1
  def update
    if @instructor.update(instructor_params)
      redirect_to instructors_path, notice: "Instructor was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /instructors/1
  def destroy
    @instructor.destroy!
    redirect_to instructors_path, notice: "Instructor was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_instructor
      @instructor = Instructor.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def instructor_params
      params.expect(instructor: [:name])
    end
end
