class FlightsController < ApplicationController
  before_action :set_flight, only: %i[ edit update destroy ]

  # GET /flights
  def index
    @flights = Flight.all
  end

  # GET /flights/new
  def new
    @flight = Flight.new
  end

  # GET /flights/1/edit
  def edit
  end

  # POST /flights
  def create
    @flight = Flight.new(flight_params)

    if @flight.save
      redirect_to flights_path, notice: "Flight was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /flights/1
  def update
    if @flight.update(flight_params)
      redirect_to flights_path, notice: "Flight was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /flights/1
  def destroy
    @flight.destroy!
    redirect_to flights_path, notice: "Flight was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_flight
      @flight = Flight.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def flight_params
      params.expect(flight: [ :duration, :note, :flying_session_id ])
    end
end
