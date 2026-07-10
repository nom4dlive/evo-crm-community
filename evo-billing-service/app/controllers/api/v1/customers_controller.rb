# Api::V1::CustomersController — REST endpoints for customer management
# Ref: Spec P2-AC-01
#
# Tenants create customers (synced with Asaas) to charge their contacts.
# Requires admin role.

class Api::V1::CustomersController < ApplicationController
  include AuthenticatedRequest

  before_action :require_admin!
  before_action :set_customer, only: [:show, :destroy]

  # GET /api/v1/customers
  def index
    customers = Customer.order(created_at: :desc).page(params[:page]).per(params[:per_page] || 20)

    render json: {
      data: customers,
      meta: pagination_meta(customers)
    }
  end

  # GET /api/v1/customers/:id
  def show
    render json: { data: @customer }
  end

  # POST /api/v1/customers
  def create
    # Initialize customer locally first to run validations (document format, etc.)
    # We pass a temporary asaas_customer_id to satisfy presence validation during initial check
    customer = Customer.new(customer_params.merge(
      account_id:        Current.account_id,
      asaas_customer_id: "temp_#{SecureRandom.hex(8)}"
    ))

    unless customer.valid?
      render json: {
        error: "unprocessable_entity",
        message: "Validation failed",
        details: customer.errors.full_messages
      }, status: :unprocessable_entity
      return
    end

    # Sync with Asaas
    begin
      asaas_response = asaas_client.create_customer(
        name:    customer_params[:name],
        cpfCnpj: customer.cpf_cnpj, # Use the normalized document from model
        email:   customer_params[:email],
        phone:   customer_params[:phone]
      )
    rescue AsaasClient::ApiError => e
      if e.status == 400
        render json: {
          error: "asaas_validation_error",
          message: "Asaas API validation failed",
          details: e.body&.dig("errors")
        }, status: :unprocessable_entity
      else
        render json: {
          error: "asaas_api_error",
          message: e.message,
          details: e.body
        }, status: :bad_gateway
      end
      return
    end

    # Set real Asaas customer ID and persist to DB
    customer.asaas_customer_id = asaas_response["id"]

    if customer.save
      render json: { data: customer }, status: :created
    else
      render json: {
        error: "unprocessable_entity",
        message: "Validation failed",
        details: customer.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/customers/:id
  def destroy
    @customer.destroy!
    head :no_content
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(:contact_id, :name, :cpf_cnpj, :email, :phone)
  end

  def asaas_client
    @asaas_client ||= AsaasClient.new
  end
end
