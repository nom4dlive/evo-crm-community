module Api
  module V1
    # Tenant-scoped payment endpoints — Ref: Spec P4
    class PaymentsController < ApplicationController
      include AuthenticatedRequest

      before_action :require_admin!

      # POST /api/v1/payments/:id/nfe/retry
      def retry_nfe
        payment = Payment.find(params[:id])
        
        if payment.confirmed?
          # Reset error on the NfeDocument if it exists, so the job knows to start clean
          nfe_doc = payment.nfe_document
          nfe_doc&.update!(nfe_error: nil)

          NfeEmissionJob.perform_async(payment.account_id, payment.id, nil)
          render json: { data: { status: "queued", payment_id: payment.id } }
        else
          render json: { error: "unprocessable_entity", message: "Only confirmed payments can emit NF-e" },
                 status: :unprocessable_entity
        end
      end
    end
  end
end
