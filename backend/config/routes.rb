Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    get "/feed", to: "feed#index"
    resources :posts, only: [ :create, :show ] do
      # PUT likes or saves, DELETE undoes it (SPEC-003 §5).
      resource :like, only: [ :update, :destroy ]
      resource :save, only: [ :update, :destroy ]
    end

    namespace :auth do
      post "sign_in", to: "sessions#create"
      delete "sign_out", to: "sessions#destroy"
      get "google", to: "google#start"
      get "google/callback", to: "google#callback"
    end
    get "me", to: "me#show"
  end
end
