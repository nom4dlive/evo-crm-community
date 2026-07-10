require "rails_helper"

RSpec.describe "Api::V1::Subscriptions", type: :request do
  let(:account_id) { 42 }
  let(:plan) { create(:plan) }
  let(:headers) { auth_headers_for(account_id: account_id) }

  describe "GET /api/v1/subscriptions/current" do
    context "with an active subscription" do
      before do
        Current.account_id = account_id
        create(:subscription, account_id: account_id, plan: plan, status: "active")
        Current.reset
      end

      it "returns the tenant's subscription" do
        get "/api/v1/subscriptions/current", headers: headers
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["data"]["account_id"]).to eq(account_id)
      end
    end

    it "returns 404 when no subscription exists" do
      get "/api/v1/subscriptions/current", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/subscriptions" do
    let(:valid_params) { { subscription: { plan_id: plan.id, billing_cycle: "monthly" } } }

    it "creates a subscription" do
      post "/api/v1/subscriptions", params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["data"]["status"]).to eq("trial")
    end

    it "returns 409 if active subscription already exists" do
      Current.account_id = account_id
      create(:subscription, account_id: account_id, plan: plan, status: "active")
      Current.reset

      post "/api/v1/subscriptions", params: valid_params.to_json, headers: headers
      expect(response).to have_http_status(:conflict)
    end
  end

  describe "DELETE /api/v1/subscriptions/:id — cancel" do
    let!(:sub) do
      Current.account_id = account_id
      create(:subscription, account_id: account_id, plan: plan)
    ensure
      Current.reset
    end

    it "cancels the subscription" do
      delete "/api/v1/subscriptions/#{sub.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]["status"]).to eq("canceled")
    end
  end
end
