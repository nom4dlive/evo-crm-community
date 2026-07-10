require "rails_helper"
require "webmock/rspec"

RSpec.describe "Api::V1::ContactCharges", type: :request do
  before do
    WebMock.enable!
  end

  after do
    WebMock.reset!
  end

  let(:headers) { auth_headers_for(account_id: 1, role: "admin") }
  let!(:customer) do
    Current.account_id = 1
    c = Customer.create!(
      account_id: 1, contact_id: 10,
      asaas_customer_id: "cus_mocked_10", cpf_cnpj: "12345678901"
    )
    Current.account_id = nil
    c
  end

  describe "POST /api/v1/contact_charges" do
    let(:valid_attrs) do
      {
        contact_charge: {
          customer_id: customer.id,
          description: "Mensalidade CRM",
          amount_cents: 15000,
          due_date: Date.tomorrow.to_s,
          billing_method: "pix"
        }
      }
    end

    it "creates a charge synced with Asaas" do
      stub_request(:post, "https://sandbox.asaas.com/api/v3/payments")
        .to_return(
          status: 200,
          body: { id: "pay_mocked_123", invoiceUrl: "https://asaas.com/pay/123" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      post "/api/v1/contact_charges", params: valid_attrs.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)["data"]
      expect(json["asaas_charge_id"]).to eq("pay_mocked_123")
      expect(json["payment_link"]).to eq("https://asaas.com/pay/123")
    end
  end

  describe "POST /api/v1/contact_charges/:id/cancel" do
    let!(:charge) do
      Current.account_id = 1
      cc = ContactCharge.create!(
        account_id: 1, customer: customer,
        description: "Mensalidade CRM", amount_cents: 15000,
        due_date: Date.tomorrow, billing_method: "pix",
        asaas_charge_id: "pay_mocked_123", status: "pending"
      )
      Current.account_id = nil
      cc
    end

    it "cancels the charge on Asaas and updates local status" do
      stub_request(:delete, "https://sandbox.asaas.com/api/v3/payments/pay_mocked_123")
        .to_return(
          status: 200,
          body: { id: "pay_mocked_123", deleted: true }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      post "/api/v1/contact_charges/#{charge.id}/cancel", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)["data"]
      expect(json["status"]).to eq("canceled")
    end
  end
end
