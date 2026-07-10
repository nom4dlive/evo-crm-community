require "rails_helper"
require "webmock/rspec"

RSpec.describe NfeEmissionJob, type: :job do
  before do
    WebMock.enable!
  end

  after do
    Current.reset
    WebMock.reset!
  end

  let(:asaas_api_url) { "https://sandbox.asaas.com/api" }
  let(:api_key) { "test_key" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("ASAAS_API_URL", anything).and_return(asaas_api_url)
    allow(ENV).to receive(:fetch).with("ASAAS_API_KEY", anything).and_return(api_key)
  end

  describe "#perform" do
    # Set tenant context globally for model setup
    let!(:setup_data) do
      Current.account_id = 42
      
      plan = Plan.unscoped.create!(
        name: "Pro", price_monthly_cents: 9900, price_annual_cents: 99000,
        tier: "pro", annual_discount_pct: 0, active: true
      )

      invoice = Invoice.unscoped.create!(
        account_id: 42,
        status: "open",
        currency: "BRL",
        subtotal_cents: 9900,
        total_cents: 9900
      )

      payment = Payment.unscoped.create!(
        account_id: 42,
        invoice: invoice,
        method: "pix",
        status: "confirmed",
        amount_cents: 9900,
        asaas_payment_id: "pay_asaas_123"
      )

      customer = Customer.unscoped.create!(
        account_id: 42,
        contact_id: 1,
        asaas_customer_id: "cus_123",
        name: "Guilherme Sales",
        cpf_cnpj: "12345678901",
        email: "guilherme@example.com"
      )

      contact_charge = ContactCharge.unscoped.create!(
        account_id: 42,
        customer: customer,
        description: "Serviço Nutrição",
        amount_cents: 15000,
        due_date: Date.tomorrow,
        billing_method: "pix",
        status: "confirmed",
        asaas_charge_id: "pay_asaas_456"
      )

      Current.account_id = nil # reset so job runs unscoped
      { payment: payment, contact_charge: contact_charge }
    end

    let(:payment) { setup_data[:payment] }
    let(:contact_charge) { setup_data[:contact_charge] }

    it "emits NF-e successfully for a platform payment" do
      stub_request(:post, "#{asaas_api_url}/v3/invoices")
        .with(body: { payment: "pay_asaas_123", serviceDescription: "Mensalidade do Sistema CRM" })
        .to_return(
          status: 200,
          body: {
            id: "inv_123",
            number: "001",
            pdfUrl: "https://asaas.com/nfe/inv_123.pdf",
            xmlUrl: "https://asaas.com/nfe/inv_123.xml"
          }.to_json
        )

      described_class.new.perform(42, payment.id, nil)

      nfe = Payment.unscoped.find(payment.id).nfe_document
      expect(nfe).to be_present
      expect(nfe.asaas_nfe_id).to eq("inv_123")
      expect(nfe.nfe_number).to eq("001")
      expect(nfe.pdf_url).to eq("https://asaas.com/nfe/inv_123.pdf")
      expect(nfe.nfe_error).to be_nil
    end

    it "emits NF-e successfully for a contact charge" do
      stub_request(:post, "#{asaas_api_url}/v3/invoices")
        .with(body: { payment: "pay_asaas_456", serviceDescription: "Serviço Nutrição" })
        .to_return(
          status: 200,
          body: {
            id: "inv_456",
            number: "002",
            pdfUrl: "https://asaas.com/nfe/inv_456.pdf",
            xmlUrl: "https://asaas.com/nfe/inv_456.xml"
          }.to_json
        )

      described_class.new.perform(42, nil, contact_charge.id)

      nfe = ContactCharge.unscoped.find(contact_charge.id).nfe_document
      expect(nfe).to be_present
      expect(nfe.asaas_nfe_id).to eq("inv_456")
      expect(nfe.pdf_url).to eq("https://asaas.com/nfe/inv_456.pdf")
    end

    it "handles api validation error and does not reschedule retry" do
      stub_request(:post, "#{asaas_api_url}/v3/invoices")
        .to_return(
          status: 400,
          body: {
            errors: [{ description: "Cliente sem CPF/CNPJ configurado." }]
          }.to_json
        )

      expect(described_class).not_to receive(:perform_in)

      described_class.new.perform(42, payment.id, nil)

      nfe = Payment.unscoped.find(payment.id).nfe_document
      expect(nfe).to be_present
      expect(nfe.asaas_nfe_id).to eq("failed_pay_#{payment.id}")
      expect(nfe.nfe_error).to include("Cliente sem CPF/CNPJ configurado.")
    end

    it "handles temporary api error and reschedules retry" do
      stub_request(:post, "#{asaas_api_url}/v3/invoices")
        .to_return(
          status: 500,
          body: "Internal Server Error"
        )

      expect(described_class).to receive(:perform_in).with(24.hours, 42, payment.id, nil, 2)

      described_class.new.perform(42, payment.id, nil, 1)

      nfe = Payment.unscoped.find(payment.id).nfe_document
      expect(nfe.nfe_error).to include("Asaas API error: 500")
    end
  end
end
