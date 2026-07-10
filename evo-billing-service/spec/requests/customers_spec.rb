require "rails_helper"
require "webmock/rspec"

RSpec.describe "Api::V1::Customers", type: :request do
  before do
    WebMock.enable!
  end

  after do
    WebMock.reset!
  end

  let(:headers) { auth_headers_for(account_id: 1, role: "admin") }

  describe "POST /api/v1/customers" do
    let(:valid_attrs) do
      {
        customer: {
          contact_id: 123,
          name: "Empresa Teste",
          cpf_cnpj: "12345678901",
          email: "teste@empresa.com",
          phone: "11999999999"
        }
      }
    end

    it "creates a customer and syncs with Asaas" do
      stub_request(:post, "https://sandbox.asaas.com/api/v3/customers")
        .to_return(
          status: 200,
          body: { id: "cus_mocked_123", name: "Empresa Teste" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      post "/api/v1/customers", params: valid_attrs.to_json, headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)["data"]
      expect(json["asaas_customer_id"]).to eq("cus_mocked_123")
      expect(json["contact_id"]).to eq(123)
    end

    it "returns bad gateway when Asaas client returns non-400 error (e.g. 500)" do
      stub_request(:post, "https://sandbox.asaas.com/api/v3/customers")
        .to_return(
          status: 500,
          body: { errors: [{ code: "internal_error", description: "Internal server error" }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      post "/api/v1/customers", params: valid_attrs.to_json, headers: headers

      expect(response).to have_http_status(:bad_gateway)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("asaas_api_error")
    end

    it "returns unprocessable entity when Asaas API returns 400 validation error" do
      stub_request(:post, "https://sandbox.asaas.com/api/v3/customers")
        .to_return(
          status: 400,
          body: { errors: [{ code: "invalid_cpf_cnpj", description: "O CPF ou CNPJ informado é inválido." }] }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect {
        post "/api/v1/customers", params: valid_attrs.to_json, headers: headers
      }.not_to change(Customer, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("asaas_validation_error")
      expect(json["details"].first["code"]).to eq("invalid_cpf_cnpj")
    end

    it "returns unprocessable entity immediately when local validation fails without calling Asaas" do
      invalid_attrs = valid_attrs.deep_merge(customer: { cpf_cnpj: "123" })

      expect {
        post "/api/v1/customers", params: invalid_attrs.to_json, headers: headers
      }.not_to change(Customer, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("unprocessable_entity")
      expect(json["details"].first).to include("must be a valid CPF")
    end
  end

  describe "GET /api/v1/customers" do
    it "lists tenant customers" do
      Current.account_id = 1
      Customer.create!(
        account_id: 1, contact_id: 1,
        asaas_customer_id: "cus_list_1", cpf_cnpj: "12345678901"
      )
      Current.account_id = nil

      get "/api/v1/customers", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["data"].size).to eq(1)
    end
  end
end
