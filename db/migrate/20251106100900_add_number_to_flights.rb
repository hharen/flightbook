class AddNumberToFlights < ActiveRecord::Migration[8.1]
  def change
    add_column :flights, :number, :integer
  end
end
