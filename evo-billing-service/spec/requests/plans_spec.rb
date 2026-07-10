require "rails_helper"

RSpec.describe "Api::V1::Plans", type: :request do
  let(:plan) { create(:plan) }

  describe "GET /api/v1/plans — public" do
    it "returns 200 without auth token" do
      create_list(:plan, 3)
      get "/api/v1/plans"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"].size).to eq(3)
    end
  end

  describe "GET /api/v1/plans/:id — public" do
    it "returns 200 for existing plan" do
      get "/api/v1/plans/#{plan.id}"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]["id"]).to eq(plan.id)
    end

    it "returns 404 for missing plan" do
      get "/api/v1/plans/99999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/plans — superadmin only" do
    let(:valid_attrs) do
      {
        plan: {
          name: "Enterprise", slug: "enterprise", tier: "enterprise",
          price_monthly_cents: 29900, price_annual_cents: 299000,
          annual_discount_pct: 17, limit_instances: 50,
          limit_agents: 100, limit_messages_per_month: 500_000
        }
      }
    end

    it "creates plan for superadmin" do
      post "/api/v1/plans", params: valid_attrs.to_json,
                            headers: superadmin_headers
      expect(response).to have_http_status(:created)
    end

    it "returns 401 without auth" do
      post "/api/v1/plans", params: valid_attrs.to_json,
                            headers: { "Content-Type" => "application/json" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 403 for non-superadmin" do
      post "/api/v1/plans", params: valid_attrs.to_json,
                            headers: auth_headers_for(account_id: 1, role: "admin")
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/plans/:id — soft-delete" do
    it "sets active=false, does not destroy record" do
      delete "/api/v1/plans/#{plan.id}", headers: superadmin_headers
      expect(response).to have_http_status(:no_content)
      expect(plan.reload.active).to be false
    end
  end
end
