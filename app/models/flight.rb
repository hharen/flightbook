class Flight < ApplicationRecord
  belongs_to :flying_session

  def show_duration
    return "-" if duration.nil?

    "%.1f" % duration
  end
end
