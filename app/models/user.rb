class User < ApplicationRecord
  has_many :flying_sessions, dependent: :destroy
  belongs_to :creator, class_name: "User", foreign_key: :created_by_id, optional: true
  has_many :created_users, class_name: "User", foreign_key: :created_by_id

  has_secure_password

  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_save { self.email = email.downcase.strip }

  # Default scope to order by name alphabetically
  default_scope { order(:name) }

  def total_flight_time
    flying_sessions.total_flight_time
  end
end
