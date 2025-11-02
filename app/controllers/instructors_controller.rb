class InstructorsController < ApplicationController
  before_action :set_instructor, only: %i[ show edit update destroy ]

  # GET /instructors
  def index
    @instructors = Instructor.all
  end

  # GET /instructors/1
  def show
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
      redirect_to @instructor, notice: "Instructor was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /instructors/1
  def update
    if @instructor.update(instructor_params)
      redirect_to @instructor, notice: "Instructor was successfully updated.", status: :see_other
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
      params.expect(instructor: [ :name ])
    end
end
