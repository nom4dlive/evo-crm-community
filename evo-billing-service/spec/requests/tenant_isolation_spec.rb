require "rails_helper"

# CRITICAL TENANT ISOLATION TEST — Ref: Spec P1-AC-06, ADR-002
# Verifies that tenant A cannot access records belonging to tenant B
# This spec MUST pass before any Phase 1 ship gate.

RSpec.describe "Tenant Isolation", type: :request do
  let(:tenant_a_id) { 101 }
  let(:tenant_b_id) { 202 }

  let(:plan) { create(:plan) }

  let!(:invoice_a) do
    Current.account_id = tenant_a_id
    create(:invoice, account_id: tenant_a_id, subscription: create(:subscription, account_id: tenant_a_id, plan: plan))
  ensure
    Current.reset
  end

  let!(:invoice_b) do
    Current.account_id = tenant_b_id
    create(:invoice, account_id: tenant_b_id, subscription: create(:subscription, account_id: tenant_b_id, plan: plan))
  ensure
    Current.reset
  end

  describe "Invoice isolation" do
    it "tenant A does NOT see tenant B invoices in list" do
      get "/api/v1/invoices", headers: auth_headers_for(account_id: tenant_a_id)
      expect(response).to have_http_status(:ok)

      ids = JSON.parse(response.body)["data"].map { |i| i["id"] }
      expect(ids).to include(invoice_a.id)
      expect(ids).not_to include(invoice_b.id)
    end

    it "tenant A cannot fetch tenant B invoice by ID" do
      get "/api/v1/invoices/#{invoice_b.id}", headers: auth_headers_for(account_id: tenant_a_id)
      expect(response).to have_http_status(:not_found)
    end

    it "tenant B does NOT see tenant A invoices in list" do
      get "/api/v1/invoices", headers: auth_headers_for(account_id: tenant_b_id)

      ids = JSON.parse(response.body)["data"].map { |i| i["id"] }
      expect(ids).to include(invoice_b.id)
      expect(ids).not_to include(invoice_a.id)
    end
  end

  describe "Subscription isolation" do
    it "tenant A current subscription is only tenant A's" do
      get "/api/v1/subscriptions/current", headers: auth_headers_for(account_id: tenant_a_id)
      expect(response).to have_http_status(:ok)

      data = JSON.parse(response.body)["data"]
      expect(data["account_id"]).to eq(tenant_a_id)
    end
  end

  describe "nil account_id guard" do
    it "raises TenantContextMissing when account_id is nil on create" do
      Current.reset  # account_id = nil
      expect {
        Invoice.create!(
          account_id: nil,
          status: "open",
          subtotal_cents: 100,
          total_cents: 100,
          currency: "BRL"
        )
      }.to raise_error(TenantContextMissing)
    end
  end
end
