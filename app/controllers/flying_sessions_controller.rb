class FlyingSessionsController < ApplicationController
  before_action :set_flying_session, only: %i[ show edit update destroy ]

  # GET /flying_sessions or /flying_sessions.json
  def index
    @flying_sessions = FlyingSession.all
  end

  # GET /flying_sessions/1 or /flying_sessions/1.json
  def show
  end

  # GET /flying_sessions/new
  def new
    @flying_session = FlyingSession.new
  end

  # GET /flying_sessions/1/edit
  def edit
  end

  # POST /flying_sessions or /flying_sessions.json
  def create
    @flying_session = FlyingSession.new(flying_session_params)

    respond_to do |format|
      if @flying_session.save
        format.html { redirect_to @flying_session, notice: "Flying session was successfully created." }
        format.json { render :show, status: :created, location: @flying_session }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @flying_session.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /flying_sessions/1 or /flying_sessions/1.json
  def update
    respond_to do |format|
      if @flying_session.update(flying_session_params)
        format.html { redirect_to @flying_session, notice: "Flying session was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @flying_session }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @flying_session.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /flying_sessions/1 or /flying_sessions/1.json
  def destroy
    @flying_session.destroy!

    respond_to do |format|
      format.html { redirect_to flying_sessions_path, notice: "Flying session was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
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
