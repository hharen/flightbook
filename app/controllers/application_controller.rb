class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :set_locale

  helper_method :current_user

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def authenticate_user!
    redirect_to new_session_path unless current_user
  end

  def require_admin!
    redirect_to root_path, alert: t("flash.authorization.not_authorized") unless current_user&.admin?
  end

  def set_locale
    locale = session[:locale] || I18n.default_locale
    I18n.locale = I18n.available_locales.map(&:to_s).include?(locale.to_s) ? locale : I18n.default_locale
  end
end
