class Instructor < ApplicationRecord
  has_many :flying_sessions, dependent: :destroy
end
