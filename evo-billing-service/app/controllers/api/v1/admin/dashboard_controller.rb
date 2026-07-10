module Api
  module V1
    module Admin
      class DashboardController < ApplicationController
        include AuthenticatedRequest
        before_action :require_superadmin!

        # GET /api/v1/admin/dashboard
        def index
          # MRR calculation
          subscriptions = Subscription.unscoped.where(status: %w[active trial past_due])
          mrr_cents = subscriptions.sum do |sub|
            plan = sub.plan
            if plan
              if sub.billing_cycle == "annual"
                plan.price_annual_cents / 12
              else
                plan.price_monthly_cents
              end
            else
              0
            end
          end

          # Churn count (canceled in the current month)
          churn_count = Subscription.unscoped
                                    .where(status: "canceled")
                                    .where("canceled_at >= ?", Time.current.beginning_of_month)
                                    .count

          # Overdue count
          overdue_count = Subscription.unscoped.where(status: "past_due").count

          # Revenue chart (last 12 months, confirmed payments)
          payments = Payment.unscoped
                            .where(status: "confirmed")
                            .where.not(paid_at: nil)
                            .where("paid_at >= ?", 12.months.ago.beginning_of_month)

          revenue_by_month = payments.group_by { |p| p.paid_at.strftime("%Y-%m") }
          
          # Build a clean chronological list of last 12 months
          revenue_chart = (0..11).reverse_each.map do |i|
            month_str = i.months.ago.strftime("%Y-%m")
            p_list = revenue_by_month[month_str] || []
            {
              month: month_str,
              amount_cents: p_list.sum(&:amount_cents)
            }
          end

          render json: {
            data: {
              mrr_cents: mrr_cents,
              churn_count: churn_count,
              overdue_count: overdue_count,
              revenue_chart: revenue_chart
            }
          }
        end
      end
    end
  end
end
