module Api
  module V1
    module Admin
      class SubscriptionsController < ApplicationController
        include AuthenticatedRequest
        before_action :require_superadmin!

        # GET /api/v1/admin/subscriptions
        def index
          @subscriptions = Subscription.unscoped
          if params[:status].present?
            @subscriptions = @subscriptions.where(status: params[:status])
          end
          @subscriptions = @subscriptions.order(created_at: :desc).page(params[:page]).per(25)

          render json: {
            data: @subscriptions.map { |s| subscription_json(s) },
            meta: pagination_meta(@subscriptions)
          }
        end

        private

        def subscription_json(sub)
          {
            id: sub.id,
            account_id: sub.account_id,
            plan_id: sub.plan_id,
            billing_cycle: sub.billing_cycle,
            status: sub.status,
            trial_ends_at: sub.trial_ends_at&.iso8601,
            current_period_start: sub.current_period_start&.iso8601,
            current_period_end: sub.current_period_end&.iso8601,
            grace_period_ends_at: sub.grace_period_ends_at&.iso8601,
            canceled_at: sub.canceled_at&.iso8601,
            created_at: sub.created_at&.iso8601
          }
        end
      end
    end
  end
end
