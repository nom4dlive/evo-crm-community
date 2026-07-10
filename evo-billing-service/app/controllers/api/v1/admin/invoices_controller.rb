module Api
  module V1
    module Admin
      # Superadmin cross-tenant invoice list — Ref: Spec P1-AC-10
      class InvoicesController < ApplicationController
        include AuthenticatedRequest
        before_action :require_superadmin!

        # GET /api/v1/admin/invoices — all tenants, optional ?account_id= filter
        def index
          @invoices = Invoice.unscoped
                             .then { |q| params[:account_id] ? q.where(account_id: params[:account_id]) : q }
                             .order(created_at: :desc)
                             .page(params[:page]).per(25)

          render json: {
            data: @invoices.map { |i| invoice_json(i) },
            meta: pagination_meta(@invoices)
          }
        end

        # GET /api/v1/admin/invoices/:id
        def show
          @invoice = Invoice.unscoped.find(params[:id])
          render json: { data: invoice_json(@invoice) }
        end

        private

        def pundit_user
          { account_id: Current.account_id, user_id: Current.user_id, role: Current.role }
        end

        def invoice_json(inv)
          {
            id: inv.id,
            account_id: inv.account_id,
            subscription_id: inv.subscription_id,
            status: inv.status,
            subtotal_cents: inv.subtotal_cents,
            total_cents: inv.total_cents,
            currency: inv.currency,
            due_date: inv.due_date&.iso8601,
            paid_at: inv.paid_at&.iso8601,
            created_at: inv.created_at&.iso8601
          }
        end
      end
    end
  end
end
