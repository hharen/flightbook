class User < ApplicationRecord
  has_many :flying_sessions, dependent: :destroy

  has_secure_password

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_save { self.email = email.downcase.strip }

  # Default scope to order by name alphabetically
  default_scope { order(:name) }

  def total_flight_time
    flying_sessions.total_flight_time
  end
end
