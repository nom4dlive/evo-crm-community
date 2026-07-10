require "rails_helper"
require "webmock/rspec"

RSpec.describe AsaasClient do
  let(:client) { described_class.new(api_key: "test_api_key") }
  let(:base_url) { "https://sandbox.asaas.com/api" }

  before do
    WebMock.enable!
  end

  after do
    WebMock.reset!
  end

  describe "#create_customer" do
    it "creates a customer on Asaas" do
      stub_request(:post, "#{base_url}/v3/customers")
        .with(
          body: { name: "John", cpfCnpj: "12345678901" }.to_json,
          headers: { "access_token" => "test_api_key", "Content-Type" => "application/json" }
        )
        .to_return(
          status: 200,
          body: { id: "cus_abc123", name: "John" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = client.create_customer(name: "John", cpfCnpj: "12345678901")
      expect(result["id"]).to eq("cus_abc123")
    end

    it "raises ApiError on failure" do
      stub_request(:post, "#{base_url}/v3/customers")
        .to_return(
          status: 400,
          body: { errors: [{ code: "invalid", description: "CPF/CNPJ inválido" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { client.create_customer(name: "X", cpfCnpj: "bad") }
        .to raise_error(AsaasClient::ApiError, /CPF\/CNPJ inválido/)
    end
  end

  describe "#create_charge" do
    it "creates a charge on Asaas" do
      stub_request(:post, "#{base_url}/v3/payments")
        .to_return(
          status: 200,
          body: {
            id: "pay_xyz789",
            invoiceUrl: "https://asaas.com/pay/xyz789"
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = client.create_charge(
        customer: "cus_abc123",
        billingType: "PIX",
        value: 150.00,
        dueDate: "2026-07-15",
        description: "Consulta"
      )

      expect(result["id"]).to eq("pay_xyz789")
      expect(result["invoiceUrl"]).to be_present
    end
  end

  describe "#get_charge" do
    it "retrieves charge details" do
      stub_request(:get, "#{base_url}/v3/payments/pay_xyz789")
        .to_return(
          status: 200,
          body: { id: "pay_xyz789", status: "CONFIRMED" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = client.get_charge("pay_xyz789")
      expect(result["status"]).to eq("CONFIRMED")
    end
  end

  describe "#cancel_charge" do
    it "cancels a charge" do
      stub_request(:delete, "#{base_url}/v3/payments/pay_xyz789")
        .to_return(
          status: 200,
          body: { id: "pay_xyz789", deleted: true }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = client.cancel_charge("pay_xyz789")
      expect(result["deleted"]).to be true
    end
  end
end
