require "rails_helper"

RSpec.describe "Admin Reports API", type: :request do
  include AuthHelpers

  let(:headers) do
    superadmin_headers(account_id: 1)
  end

  before do
    # Create some NfeDocuments
    Current.account_id = 1
    NfeDocument.unscoped.create!(
      account_id: 1,
      asaas_nfe_id: "inv_issued",
      pdf_url: "https://example.com/issued.pdf",
      created_at: 5.days.ago
    )
    NfeDocument.unscoped.create!(
      account_id: 1,
      asaas_nfe_id: "inv_failed",
      nfe_error: "Some error",
      created_at: 3.days.ago
    )
    NfeDocument.unscoped.create!(
      account_id: 1,
      asaas_nfe_id: "inv_pending",
      created_at: 1.day.ago
    )
    Current.account_id = nil
  end

  describe "GET /api/v1/admin/reports/fiscal" do
    it "returns correct counts for fiscal documents" do
      get "/api/v1/admin/reports/fiscal", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["total_nfe_issued"]).to eq(1)
      expect(json["total_nfe_failed"]).to eq(1)
      expect(json["total_nfe_pending"]).to eq(1)
    end

    it "filters results by from and to period" do
      get "/api/v1/admin/reports/fiscal?from=#{2.days.ago.iso8601}&to=#{Time.now.iso8601}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["total_nfe_issued"]).to eq(0)
      expect(json["total_nfe_failed"]).to eq(0)
      expect(json["total_nfe_pending"]).to eq(1)
    end
  end
end
