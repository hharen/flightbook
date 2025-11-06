Rails.application.routes.draw do
  resources :flights, except: [:show]
  resources :flying_sessions do
    collection do
      post :get_flying_sessions
    end
  end
  resources :instructors, except: [:show]
  resources :users, except: [:show] do
    resources :flying_sessions, only: [:index, :show], path: "sessions"
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "flying_sessions#index"
end
