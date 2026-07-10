require "rails_helper"

RSpec.describe "Payments & Contact Charges NF-e Retries", type: :request do
  include AuthHelpers

  let(:headers) do
    auth_headers_for(account_id: 42, role: "admin", user_id: 123)
  end

  before do
    Current.account_id = 42
    
    @plan = Plan.unscoped.create!(
      name: "Pro", price_monthly_cents: 9900, price_annual_cents: 99000,
      tier: "pro", annual_discount_pct: 0, active: true
    )

    @invoice = Invoice.unscoped.create!(
      account_id: 42,
      status: "open",
      currency: "BRL",
      subtotal_cents: 9900,
      total_cents: 9900
    )

    @payment = Payment.unscoped.create!(
      account_id: 42,
      invoice: @invoice,
      method: "pix",
      status: "confirmed",
      amount_cents: 9900,
      asaas_payment_id: "pay_asaas_123"
    )

    @customer = Customer.unscoped.create!(
      account_id: 42,
      contact_id: 1,
      asaas_customer_id: "cus_123",
      name: "Guilherme Sales",
      cpf_cnpj: "12345678901",
      email: "guilherme@example.com"
    )

    @contact_charge = ContactCharge.unscoped.create!(
      account_id: 42,
      customer: @customer,
      description: "Serviço Nutrição",
      amount_cents: 15000,
      due_date: Date.tomorrow,
      billing_method: "pix",
      status: "confirmed",
      asaas_charge_id: "pay_asaas_456"
    )

    Current.account_id = nil
  end

  describe "POST /api/v1/payments/:id/nfe/retry" do
    it "queues a manual NF-e retry for confirmed payments" do
      expect(NfeEmissionJob).to receive(:perform_async).with(42, @payment.id, nil)

      post "/api/v1/payments/#{@payment.id}/nfe/retry", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]["status"]).to eq("queued")
    end

    it "returns 422 for unconfirmed payments" do
      Current.account_id = 42
      @payment.update!(status: "pending")
      Current.account_id = nil

      post "/api/v1/payments/#{@payment.id}/nfe/retry", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/contact_charges/:id/nfe/retry" do
    it "queues a manual NF-e retry for confirmed charges" do
      expect(NfeEmissionJob).to receive(:perform_async).with(42, nil, @contact_charge.id)

      post "/api/v1/contact_charges/#{@contact_charge.id}/nfe/retry", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"]["status"]).to eq("queued")
    end

    it "returns 422 for unconfirmed charges" do
      Current.account_id = 42
      @contact_charge.update!(status: "pending")
      Current.account_id = nil

      post "/api/v1/contact_charges/#{@contact_charge.id}/nfe/retry", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
