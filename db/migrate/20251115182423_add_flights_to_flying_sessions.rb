class AddFlightsToFlyingSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :flying_sessions, :flights, :integer, null: false, default: 0

    # Add an index for performance when querying by flights count
    add_index :flying_sessions, :flights
  end
end
