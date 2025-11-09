class AddDurationToFlyingSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :flying_sessions, :duration, :integer
  end
end
