class LocaleController < ApplicationController
  skip_before_action :authenticate_user!

  def update
    locale_param = params[:locale].to_s
    if I18n.available_locales.map(&:to_s).include?(locale_param)
      session[:locale] = locale_param.to_sym
    end
    redirect_back fallback_location: root_path
  end
end
