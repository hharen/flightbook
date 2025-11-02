class FlyingSessionsController < ApplicationController
  before_action :set_flying_session, only: %i[ show edit update destroy ]

  # GET /flying_sessions
  def index
    @flying_sessions = FlyingSession.all
  end

  # GET /flying_sessions/1
  def show
  end

  # GET /flying_sessions/new
  def new
    @flying_session = FlyingSession.new
  end

  # GET /flying_sessions/1/edit
  def edit
  end

  # POST /flying_sessions
  def create
    @flying_session = FlyingSession.new(flying_session_params)

    if @flying_session.save
      redirect_to @flying_session, notice: "Flying session was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /flying_sessions/1
  def update
    if @flying_session.update(flying_session_params)
      redirect_to @flying_session, notice: "Flying session was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /flying_sessions/1
  def destroy
    @flying_session.destroy!
    redirect_to flying_sessions_path, notice: "Flying session was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_flying_session
      @flying_session = FlyingSession.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def flying_session_params
      params.expect(flying_session: [ :date, :time, :flight_time, :note, :user_id, :instructor_id ])
    end
end
