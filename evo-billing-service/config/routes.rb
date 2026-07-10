Rails.application.routes.draw do
  # Health check — no auth required (Spec P1-AC-11)
  get "/health", to: "health#show"

  # Asaas webhook ingress — HMAC verified, no JWT (Spec P2-AC-03)
  post "/webhooks/asaas", to: "webhooks/asaas#create"

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

      # Customers — tenant admin manages Asaas-synced customers (Spec P2-AC-01)
      resources :customers, only: [:index, :show, :create, :destroy]

      # Contact Charges — tenant admin charges contacts (Spec P2-AC-02)
      resources :contact_charges, only: [:index, :show, :create] do
        member do
          post :cancel
        end
      end

      namespace :admin do
        # Superadmin cross-tenant invoice list (Spec P1-AC-10)
        resources :invoices, only: [:index, :show]
      end
    end
  end
end
