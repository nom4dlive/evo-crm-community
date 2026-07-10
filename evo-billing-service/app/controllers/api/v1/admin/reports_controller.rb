module Api
  module V1
    module Admin
      # Superadmin reports endpoints — Ref: Spec P4-AC-04
      class ReportsController < ApplicationController
        include AuthenticatedRequest
        before_action :require_superadmin!

        # GET /api/v1/admin/reports/fiscal
        def fiscal
          from = params[:from].present? ? Time.zone.parse(params[:from]) : 30.days.ago.beginning_of_day
          to   = params[:to].present? ? Time.zone.parse(params[:to]) : Time.zone.now.end_of_day

          docs = NfeDocument.unscoped.where(created_at: from..to)

          total_issued  = docs.where.not(pdf_url: nil).where(nfe_error: nil).count
          total_failed  = docs.where.not(nfe_error: nil).count
          total_pending = docs.where(pdf_url: nil, nfe_error: nil).count

          render json: {
            total_nfe_issued: total_issued,
            total_nfe_pending: total_pending,
            total_nfe_failed: total_failed,
            period: {
              from: from.iso8601,
              to: to.iso8601
            }
          }
        end
      end
    end
  end
end
