Rails.application.routes.draw do
  # Health check — no auth required (Spec P1-AC-11)
  get "/health", to: "health#show"

  namespace :api do
    namespace :v1 do
      # Plans — public GET, superadmin POST/PATCH/DELETE (Spec P1-AC-08)
      resources :plans, only: [:index, :show, :create, :update, :destroy]

      # Subscriptions — tenant admin (Spec P1-AC-09)
      resources :subscriptions, only: [:create, :update, :destroy] do
        collection do
          get :current
        end
      end

      # Invoices — tenant-scoped read (Spec P1-AC-10)
      resources :invoices, only: [:index, :show]

      namespace :admin do
        # Superadmin cross-tenant invoice list (Spec P1-AC-10)
        resources :invoices, only: [:index, :show]
      end
    end
  end
end
