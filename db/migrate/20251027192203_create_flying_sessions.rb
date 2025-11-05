class CreateFlyingSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :flying_sessions do |t|
      t.datetime :date_time, null: false
      t.string :note
      t.references :user, null: false, foreign_key: true
      t.references :instructor, null: true, foreign_key: true

      t.timestamps
    end
  end
end
