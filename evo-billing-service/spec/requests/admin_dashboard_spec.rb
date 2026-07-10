require "rails_helper"

RSpec.describe "Api::V1::Admin::Dashboard", type: :request do
  let(:account_id) { 1 }
  let(:plan_monthly) { create(:plan, price_monthly_cents: 10000, price_annual_cents: 100000) }
  let(:superadmin_headers_obj) { superadmin_headers(account_id: account_id) }
  let(:regular_headers) { auth_headers_for(account_id: account_id, role: "admin") }

  describe "GET /api/v1/admin/dashboard" do
    context "when unauthorized" do
      it "returns 401 when missing token" do
        get "/api/v1/admin/dashboard"
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 403 when not a superadmin" do
        get "/api/v1/admin/dashboard", headers: regular_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when authenticated as superadmin" do
      before do
        Current.account_id = account_id
        # Subscriptions for MRR calculation
        sub1 = create(:subscription, account_id: 1, plan: plan_monthly, status: "active", billing_cycle: "monthly")
        sub2 = create(:subscription, account_id: 2, plan: plan_monthly, status: "active", billing_cycle: "annual")
        # Overdue subscription
        create(:subscription, account_id: 3, plan: plan_monthly, status: "past_due", billing_cycle: "monthly")
        # Canceled subscription (churn)
        create(:subscription, account_id: 4, plan: plan_monthly, status: "canceled", billing_cycle: "monthly", canceled_at: Time.current)

        # Paid payments for revenue chart
        inv1 = create(:invoice, account_id: 1, subscription: sub1)
        create(:payment, account_id: 1, invoice: inv1, status: "confirmed", amount_cents: 10000, paid_at: Time.current)
        inv2 = create(:invoice, account_id: 2, subscription: sub2)
        create(:payment, account_id: 2, invoice: inv2, status: "confirmed", amount_cents: 100000, paid_at: 1.month.ago)
        Current.reset
      end

      it "calculates correct dashboard metrics" do
        get "/api/v1/admin/dashboard", headers: superadmin_headers_obj
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)["data"]

        # sub1 monthly = 100.00, sub2 annual = 1000.00 / 12 = 83.33, sub3 monthly = 100.00 => MRR = 283.33 (in cents: 28333)
        expect(json["mrr_cents"]).to eq(28333)
        expect(json["churn_count"]).to eq(1)
        expect(json["overdue_count"]).to eq(1)
        expect(json["revenue_chart"]).to be_an(Array)
        expect(json["revenue_chart"].length).to be >= 1
      end
    end
  end
end
