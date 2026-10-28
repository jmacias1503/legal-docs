Rails.application.routes.draw do
  devise_for :users

  resources :documents do
    member do
      post :reprocess
      patch :confirm
      get :fill
      post :issue
    end
  end
  resources :templates
  resource :subscription, only: %i[show update]
  resource :api_token, only: %i[show create destroy]

  # RF-03: verificación pública de documentos emitidos (destino del QR).
  get "verificar/:token" => "verifications#show", as: :verification
  post "verificar/:token" => "verifications#create"

  # RNF-06
  namespace :api do
    namespace :v1 do
      resources :documents, only: %i[index show create update] do
        get :fill, on: :member
      end
      resources :templates, only: %i[index show]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "documents#index"
end
