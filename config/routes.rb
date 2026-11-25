Rails.application.routes.draw do
  post "/rails/active_storage/direct_uploads", to: "image_direct_uploads#create"
  mount RailsIcons::Engine, at: "/rails_icons"
  resource :session
  resource :registration, only: [ :new, :create ]
  resource :profile, only: [ :show, :edit, :update ]
  resources :passwords, param: :token
  root "dashboard#index"
  get "picks", to: "picks#index"
  get "my_picks", to: "my_picks#index"
  patch "my_picks/:id", to: "my_picks#update", as: :my_pick
  resources :comments, only: [ :create ]
  resources :games, only: [ :index, :show ] do
    resources :comments, only: [ :create ]
  end
  get "leaders", to: "leaders#index"
  get "legends", to: "legends#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
