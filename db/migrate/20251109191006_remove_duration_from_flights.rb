class RemoveDurationFromFlights < ActiveRecord::Migration[8.1]
  def change
    remove_column :flights, :duration, :integer
  end
end
