require "rails_helper"

RSpec.describe "Api::V1::Admin::Subscriptions", type: :request do
  let(:account_id) { 1 }
  let(:plan) { create(:plan) }
  let(:superadmin_headers_obj) { superadmin_headers(account_id: account_id) }
  let(:regular_headers) { auth_headers_for(account_id: account_id, role: "admin") }

  describe "GET /api/v1/admin/subscriptions" do
    context "when unauthorized" do
      it "returns 401 when missing token" do
        get "/api/v1/admin/subscriptions"
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 403 when not a superadmin" do
        get "/api/v1/admin/subscriptions", headers: regular_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when authenticated as superadmin" do
      before do
        Current.account_id = account_id
        create(:subscription, account_id: 1, plan: plan, status: "active")
        create(:subscription, account_id: 2, plan: plan, status: "past_due")
        Current.reset
      end

      it "returns all subscriptions across tenants" do
        get "/api/v1/admin/subscriptions", headers: superadmin_headers_obj
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"].length).to eq(2)
      end

      it "filters subscriptions by status" do
        get "/api/v1/admin/subscriptions?status=past_due", headers: superadmin_headers_obj
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["data"].length).to eq(1)
        expect(json["data"].first["status"]).to eq("past_due")
      end
    end
  end
end
