class Flight < ApplicationRecord
  belongs_to :flying_session

  def show_duration
    "%.1f" % duration
  end
end
