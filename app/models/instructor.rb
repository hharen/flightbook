class Instructor < ApplicationRecord
  has_many :flying_sessions, dependent: :destroy

  # Default scope to order by name alphabetically
  default_scope { order(:name) }
end
