class FlightsController < ApplicationController
  before_action :set_flight, only: %i[show edit update destroy]

  # GET /flights
  def index
    @users = User.all

    if params[:user_id].present?
      @selected_user = User.find(params[:user_id])
    else
      # Preselect user 'Hana' by default
      @selected_user = User.find_by(name: "Hana")
    end

    if @selected_user
      @flights = Flight.joins(:flying_session).where(flying_sessions: { user_id: @selected_user.id })
      @total_flight_time = @selected_user.flying_sessions.total_flight_time
    else
      @flights = Flight.all
    end
  end

  # GET /flights/new
  def new
    @flight = Flight.new

    # Pre-select flying session if passed as parameter
    if params[:flying_session_id].present?
      @flight.flying_session_id = params[:flying_session_id]
    end
  end

  # GET /flights/1
  def show
    if turbo_frame_request?
      render partial: 'flight_row', locals: { flight: @flight }
    else
      redirect_to @flight.flying_session
    end
  end

  # GET /flights/1/edit
  def edit
    # The edit view will handle rendering based on turbo_frame_request?
  end

  # POST /flights
  def create
    @flight = Flight.new(flight_params)

    if @flight.save
      redirect_to @flight.flying_session, notice: "Flight was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /flights/1
  def update
    if @flight.update(flight_params)
      respond_to do |format|
        format.html { redirect_to @flight.flying_session, notice: "Flight was successfully updated.", status: :see_other }
        format.turbo_stream # Will render update.turbo_stream.erb
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /flights/1
  def destroy
    @flight.destroy!
    redirect_to @flight.flying_session, notice: "Flight was successfully deleted.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_flight
      @flight = Flight.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def flight_params
      params.expect(flight: [:note, :flying_session_id])
    end
end
