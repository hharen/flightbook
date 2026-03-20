class AddAdminAndCreatorToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin, :boolean, default: false, null: false
    add_column :users, :created_by_id, :integer, null: true
    add_index :users, :created_by_id
  end
end
