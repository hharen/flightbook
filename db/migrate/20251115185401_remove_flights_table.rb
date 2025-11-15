class RemoveFlightsTable < ActiveRecord::Migration[8.1]
  def up
    drop_table :flights
  end

  def down
    # Recreate flights table structure (for rollback purposes)
    create_table :flights do |t|
      t.integer :number
      t.text :note
      t.references :flying_session, null: false, foreign_key: true
      t.timestamps
    end

    add_index :flights, :flying_session_id
  end
end
