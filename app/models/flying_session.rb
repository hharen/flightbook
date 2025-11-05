class FlyingSession < ApplicationRecord
  belongs_to :user
  belongs_to :instructor, optional: true
  has_many :flights, dependent: :destroy

  # Default scope to order by newest sessions first
  default_scope { order(date_time: :desc) }
end
