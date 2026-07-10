module Api
  module V1
    class SubscriptionsController < ApplicationController
      include AuthenticatedRequest

      before_action :set_subscription, only: [:update, :destroy]

      # GET /api/v1/subscriptions/current — tenant's active subscription (Spec P1-AC-09)
      def current
        @subscription = Subscription.where(status: %w[trial active past_due]).first
        if @subscription
          render json: { data: subscription_json(@subscription) }
        else
          render json: { error: "not_found", message: "No active subscription found" },
                 status: :not_found
        end
      end

      # POST /api/v1/subscriptions — create (Spec P1-AC-09)
      def create
        authorize Subscription, policy_class: SubscriptionPolicy

        @subscription = Subscription.new(subscription_params)
        @subscription.account_id = Current.account_id

        if @subscription.save
          render json: { data: subscription_json(@subscription) }, status: :created
        else
          # 409 if active subscription already exists (Spec P1-AC-09)
          if @subscription.errors[:base].any? { |e| e.include?("already exists") }
            render json: { error: "conflict", message: @subscription.errors[:base].first },
                   status: :conflict
          else
            render json: { error: "unprocessable_entity", details: @subscription.errors.full_messages },
                   status: :unprocessable_entity
          end
        end
      end

      # PATCH /api/v1/subscriptions/:id — change plan or billing_cycle (Spec P1-AC-09)
      def update
        authorize @subscription, policy_class: SubscriptionPolicy

        if @subscription.update(update_subscription_params)
          render json: { data: subscription_json(@subscription) }
        else
          render json: { error: "unprocessable_entity", details: @subscription.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/subscriptions/:id — cancel (Spec P1-AC-09)
      def destroy
        authorize @subscription, policy_class: SubscriptionPolicy
        @subscription.cancel!
        render json: { data: subscription_json(@subscription) }
      end

      private

      def set_subscription
        @subscription = Subscription.find(params[:id])
      end

      def subscription_params
        params.require(:subscription).permit(:plan_id, :billing_cycle)
      end

      def update_subscription_params
        params.require(:subscription).permit(:plan_id, :billing_cycle)
      end

      def pundit_user
        { account_id: Current.account_id, user_id: Current.user_id, role: Current.role }
      end

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
