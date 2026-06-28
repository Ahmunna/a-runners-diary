Rails.application.routes.draw do
  devise_for :users

  namespace :onboarding do
    resource :profile, only: [ :new, :create, :edit, :update ], controller: "profiles"
    resource :race, only: [ :new, :create ], controller: "races"
  end

  post "push_subscriptions", to: "push_subscriptions#create", as: :push_subscriptions
  delete "push_subscriptions", to: "push_subscriptions#destroy", as: :destroy_push_subscriptions

  resource :dashboard, only: [ :show ], controller: "dashboard"

  resource :strava_connection, only: [ :destroy ], controller: "strava_connections"
  get "strava/connect", to: "strava_connections#connect", as: :strava_connect
  get "strava/callback", to: "strava_connections#callback", as: :strava_callback
  match "strava/webhook", to: "strava_webhooks#create", via: [ :get, :post ], as: :strava_webhook
  resource :strava_sync, only: [ :create ], controller: "strava_syncs"

  resource :claude_credential, only: [ :new, :create, :edit, :update ]

  resources :nutrition_logs, only: [ :index, :new, :create, :edit, :update ]
  resources :messages, only: [ :index, :create ]

  namespace :admin do
    resources :users, only: [ :index, :show ]
  end

  root to: "dashboard#show"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
