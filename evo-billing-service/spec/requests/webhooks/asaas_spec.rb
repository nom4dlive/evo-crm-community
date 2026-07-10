require "rails_helper"

RSpec.describe "Webhooks::Asaas", type: :request do
  before do
    Current.account_id = nil # Webhooks are not tenant-scoped
  end

  after { Current.reset }

  let(:valid_secret) { "test_webhook_secret_123" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ASAAS_WEBHOOK_SECRET").and_return(valid_secret)
    allow(ENV).to receive(:fetch).with("ASAAS_WEBHOOK_SECRET", anything).and_return(valid_secret)
  end

  describe "POST /webhooks/asaas" do
    let(:payment_payload) do
      {
        id: "evt_001",
        event: "PAYMENT_CONFIRMED",
        payment: {
          id: "pay_asaas_001",
          status: "CONFIRMED"
        }
      }
    end

    context "with valid signature" do
      it "returns 200 and processes the event" do
        post "/webhooks/asaas",
             params: payment_payload.to_json,
             headers: {
               "Content-Type" => "application/json",
               "asaas-access-token" => valid_secret
             }

        expect(response).to have_http_status(:ok), "Expected 200, got: #{response.body}"
        parsed = JSON.parse(response.body)
        expect(parsed["status"]).to eq("processed")
      end

      it "stores the webhook event idempotently" do
        post "/webhooks/asaas",
             params: payment_payload.to_json,
             headers: {
               "Content-Type" => "application/json",
               "asaas-access-token" => valid_secret
             }

        expect(AsaasWebhookEvent.count).to eq(1)
        event = AsaasWebhookEvent.first
        expect(event.event_id).to eq("evt_001")
        expect(event.event_type).to eq("PAYMENT_CONFIRMED")
        expect(event).to be_processed
      end

      it "skips already-processed events" do
        AsaasWebhookEvent.create!(
          event_id: "evt_001",
          event_type: "PAYMENT_CONFIRMED",
          payload: payment_payload,
          processed: true,
          processed_at: Time.current
        )

        post "/webhooks/asaas",
             params: payment_payload.to_json,
             headers: {
               "Content-Type" => "application/json",
               "asaas-access-token" => valid_secret
             }

        expect(response).to have_http_status(:ok), "Expected 200, got: #{response.body}"
        parsed = JSON.parse(response.body)
        expect(parsed["status"]).to eq("already_processed")
      end
    end

    context "with invalid signature" do
      it "returns 401" do
        post "/webhooks/asaas",
             params: payment_payload.to_json,
             headers: {
               "Content-Type" => "application/json",
               "asaas-access-token" => "wrong_secret"
             }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "without signature" do
      it "returns 401" do
        post "/webhooks/asaas",
             params: payment_payload.to_json,
             headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "PAYMENT_CONFIRMED updates contact charge" do
      it "marks matching contact charge as confirmed" do
        Current.account_id = 1
        customer = Customer.create!(
          account_id: 1, contact_id: 1,
          asaas_customer_id: "cus_wh1", cpf_cnpj: "12345678901"
        )
        charge = ContactCharge.create!(
          account_id: 1, customer: customer,
          description: "Test", amount_cents: 10000,
          due_date: Date.tomorrow, billing_method: "pix",
          asaas_charge_id: "pay_asaas_001", status: "pending"
        )
        Current.account_id = nil

        post "/webhooks/asaas",
             params: payment_payload.to_json,
             headers: {
               "Content-Type" => "application/json",
               "asaas-access-token" => valid_secret
             }

        expect(response).to have_http_status(:ok), "Expected 200, got: #{response.body}"
        expect(charge.reload.status).to eq("confirmed")
      end
    end

    context "PAYMENT_CONFIRMED updates platform payment and unsuspends account" do
      it "updates subscription, invoice, and triggers S2S unsuspend" do
        Current.account_id = 1
        plan = Plan.create!(
          name: "Pro", price_monthly_cents: 9900, price_annual_cents: 99000,
          tier: "pro", annual_discount_pct: 0, active: true
        )
        sub = Subscription.create!(
          account_id: 1,
          plan: plan,
          billing_cycle: "monthly",
          status: "past_due",
          grace_period_ends_at: 2.days.from_now
        )
        invoice = Invoice.create!(
          account_id: 1,
          subscription: sub,
          status: "open",
          subtotal_cents: 9900,
          total_cents: 9900,
          currency: "BRL",
          due_date: Date.current
        )
        payment = Payment.create!(
          account_id: 1,
          invoice: invoice,
          method: "pix",
          status: "pending",
          amount_cents: 9900,
          asaas_payment_id: "pay_asaas_001"
        )
        Current.account_id = nil

        auth_url = "http://evo-auth:3001"
        secret = "test_internal_secret"
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("EVO_AUTH_INTERNAL_URL", anything).and_return(auth_url)
        allow(ENV).to receive(:fetch).with("INTERNAL_API_SECRET", anything).and_return(secret)

        stub_request(:post, "#{auth_url}/api/v1/internal/accounts/1/unsuspend")
          .with(headers: { "Authorization" => "Bearer #{secret}" })
          .to_return(status: 200, body: { status: "active" }.to_json)

        post "/webhooks/asaas",
             params: payment_payload.to_json,
             headers: {
               "Content-Type" => "application/json",
               "asaas-access-token" => valid_secret
             }

        expect(response).to have_http_status(:ok), "Expected 200, got: #{response.body}"
        expect(payment.reload.status).to eq("confirmed")
        expect(invoice.reload.status).to eq("paid")
        expect(sub.reload.status).to eq("active")
        expect(sub.grace_period_ends_at).to be_nil
        expect(WebMock).to have_requested(:post, "#{auth_url}/api/v1/internal/accounts/1/unsuspend")
      end
    end
  end
end
