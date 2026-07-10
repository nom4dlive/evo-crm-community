# AsaasClient — HTTP client wrapper for Asaas API
# Ref: Spec P2-AC-01, ADR-003 D4
#
# Uses Net::HTTP to avoid adding external HTTP gems.
# All calls are tenant-scoped (API key per-tenant is future; for now,
# a single platform key from ENV is used).
#
# Endpoints wrapped:
#   - create_customer(attrs)     → POST /v3/customers
#   - create_charge(attrs)       → POST /v3/payments
#   - get_charge(asaas_id)       → GET  /v3/payments/:id
#   - cancel_charge(asaas_id)    → DELETE /v3/payments/:id

require "net/http"
require "json"
require "uri"

class AsaasClient
  BASE_URL = ENV.fetch("ASAAS_API_URL", "https://sandbox.asaas.com/api").freeze

  class ApiError < StandardError
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      @status = status
      @body   = body
      super(message)
    end
  end

  def initialize(api_key: nil)
    @api_key = api_key || ENV.fetch("ASAAS_API_KEY", "")
  end

  # Create a customer on Asaas
  # @param attrs [Hash] :name, :cpfCnpj, :email, :phone
  # @return [Hash] parsed JSON response
  def create_customer(attrs)
    post("/v3/customers", attrs)
  end

  # Create a charge (payment) on Asaas
  # @param attrs [Hash] :customer, :billingType, :value, :dueDate, :description
  # @return [Hash] parsed JSON response with :id, :invoiceUrl, etc.
  def create_charge(attrs)
    post("/v3/payments", attrs)
  end

  # Get charge details
  # @param asaas_id [String] Asaas payment ID
  # @return [Hash] parsed JSON response
  def get_charge(asaas_id)
    get("/v3/payments/#{asaas_id}")
  end

  # Cancel a charge
  # @param asaas_id [String] Asaas payment ID
  # @return [Hash] parsed JSON response
  def cancel_charge(asaas_id)
    delete("/v3/payments/#{asaas_id}")
  end

  # Create an NF-e linked to a payment/charge
  # @param payment_id [String] Asaas payment/charge ID
  # @param attrs [Hash] Additional options
  # @return [Hash] parsed JSON response
  def create_nfe(payment_id, attrs = {})
    post("/v3/invoices", attrs.merge(payment: payment_id))
  end

  # Get NF-e details
  # @param nfe_id [String] Asaas invoice ID
  # @return [Hash] parsed JSON response
  def get_nfe(nfe_id)
    get("/v3/invoices/#{nfe_id}")
  end

  private

  def get(path)
    request(:get, path)
  end

  def post(path, body = {})
    request(:post, path, body)
  end

  def delete(path)
    request(:delete, path)
  end

  def request(method, path, body = nil)
    uri = URI.parse("#{BASE_URL}#{path}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10
    http.read_timeout = 30

    req = build_request(method, uri, body)
    response = http.request(req)

    parsed = JSON.parse(response.body) rescue { "raw" => response.body }

    unless response.is_a?(Net::HTTPSuccess)
      raise ApiError.new(
        "Asaas API error: #{response.code} — #{parsed['errors']&.first&.dig('description') || response.message}",
        status: response.code.to_i,
        body: parsed
      )
    end

    parsed
  end

  def build_request(method, uri, body)
    klass = case method
            when :get    then Net::HTTP::Get
            when :post   then Net::HTTP::Post
            when :delete then Net::HTTP::Delete
            else raise ArgumentError, "Unsupported HTTP method: #{method}"
            end

    req = klass.new(uri.request_uri)
    req["Content-Type"]  = "application/json"
    req["Accept"]        = "application/json"
    req["access_token"]  = @api_key

    req.body = body.to_json if body && method == :post

    req
  end
end
