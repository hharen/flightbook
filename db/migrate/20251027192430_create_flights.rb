class CreateFlights < ActiveRecord::Migration[8.0]
  def change
    create_table :flights do |t|
      t.integer :duration
      t.string :note
      t.references :flying_session, null: false, foreign_key: true

      t.timestamps
    end
  end
end
