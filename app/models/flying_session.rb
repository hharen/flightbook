class FlyingSession < ApplicationRecord
  belongs_to :user
  belongs_to :instructor
  has_many :flights
end
