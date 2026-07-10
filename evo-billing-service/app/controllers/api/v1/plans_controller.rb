module Api
  module V1
    class PlansController < ApplicationController
      # GET /api/v1/plans is public — skip auth for index/show
      # POST/PATCH/DELETE require superadmin
      before_action :authenticate_request!, except: [:index, :show]
      include AuthenticatedRequest

      # Override: allow public access for index/show
      # Re-include only for mutating actions
      skip_before_action :authenticate_request!, only: [:index, :show]

      before_action :set_plan, only: [:show, :update, :destroy]

      # GET /api/v1/plans — public (Spec P1-AC-08)
      def index
        if request.headers["Authorization"].present?
          begin
            token = extract_token_from_header
            if token
              payload = JsonWebToken.decode(token)
              Current.role = normalize_role(payload["role"])
            end
          rescue
            # Ignore token decode errors on public index
          end
        end

        if Current.superadmin?
          @plans = Plan.all.order(tier: :asc, price_monthly_cents: :asc)
        else
          @plans = Plan.active.order(tier: :asc, price_monthly_cents: :asc)
        end
        render json: { data: plans_json(@plans) }
      end

      # GET /api/v1/plans/:id — public
      def show
        render json: { data: plan_json(@plan) }
      end

      # POST /api/v1/plans — superadmin only (Spec P1-AC-08)
      def create
        authorize Plan, policy_class: PlanPolicy
        @plan = Plan.new(plan_params)
        if @plan.save
          render json: { data: plan_json(@plan) }, status: :created
        else
          render json: { error: "unprocessable_entity", details: @plan.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/plans/:id — superadmin only
      def update
        authorize @plan, policy_class: PlanPolicy
        if @plan.update(plan_params)
          render json: { data: plan_json(@plan) }
        else
          render json: { error: "unprocessable_entity", details: @plan.errors.full_messages },
                 status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/plans/:id — soft-delete (Spec P1-AC-08)
      def destroy
        authorize @plan, policy_class: PlanPolicy
        @plan.update!(active: false)
        head :no_content
      end

      private

      def set_plan
        @plan = Plan.find(params[:id])
      end

      def plan_params
        params.require(:plan).permit(
          :name, :slug, :tier, :price_monthly_cents, :price_annual_cents,
          :annual_discount_pct, :limit_instances, :limit_agents,
          :limit_messages_per_month, :active
        )
      end

      def pundit_user
        { account_id: Current.account_id, user_id: Current.user_id, role: Current.role }
      end

      def plans_json(plans)
        plans.map { |p| plan_json(p) }
      end

      def plan_json(plan)
        {
          id: plan.id, name: plan.name, slug: plan.slug, tier: plan.tier,
          price_monthly_cents: plan.price_monthly_cents,
          price_annual_cents: plan.price_annual_cents,
          annual_discount_pct: plan.annual_discount_pct,
          limit_instances: plan.limit_instances,
          limit_agents: plan.limit_agents,
          limit_messages_per_month: plan.limit_messages_per_month,
          active: plan.active,
          created_at: plan.created_at&.iso8601
        }
      end
    end
  end
end
