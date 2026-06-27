class NutritionLogsController < ApplicationController
  def index
    @nutrition_logs = current_user.nutrition_logs.order(date: :desc).limit(30)
  end

  def new
    @nutrition_log = current_user.nutrition_logs.new(date: Date.current)
  end

  def create
    @nutrition_log = current_user.nutrition_logs.new(nutrition_log_params)

    if @nutrition_log.save
      redirect_to nutrition_logs_path, notice: "Logged."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @nutrition_log = current_user.nutrition_logs.find(params[:id])
  end

  def update
    @nutrition_log = current_user.nutrition_logs.find(params[:id])

    if @nutrition_log.update(nutrition_log_params)
      redirect_to nutrition_logs_path, notice: "Updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def nutrition_log_params
    params.require(:nutrition_log).permit(:date, :calories, :protein_g, :carbs_g, :fat_g, :notes)
  end
end
