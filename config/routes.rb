Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine, at: "/jobs"

  resource :session
  resource :registration, only: [ :new, :create ]
  resources :dashboard, only: [ :index ]
  resources :passwords, param: :token
  resources :games, only: [ :index, :show ]
  resources :picks, only: [ :index ]
  resources :teams
  resources :leaders, only: [ :index ]
  resources :legends, only: [ :index ]
  resources :users do
    get "picks", to: "users/picks#index"
    put "picks", to: "users/picks#update"
    get "picks/edit", to: "users/picks#edit"
  end
  resources :venues

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "dashboard#index"
end
