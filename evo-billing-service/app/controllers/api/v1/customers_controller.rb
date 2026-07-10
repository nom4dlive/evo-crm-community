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
    # Sync with Asaas first
    asaas_response = asaas_client.create_customer(
      name:    customer_params[:name],
      cpfCnpj: customer_params[:cpf_cnpj],
      email:   customer_params[:email],
      phone:   customer_params[:phone]
    )

    customer = Customer.new(customer_params.merge(
      account_id:       Current.account_id,
      asaas_customer_id: asaas_response["id"]
    ))

    if customer.save
      render json: { data: customer }, status: :created
    else
      render json: {
        error: "unprocessable_entity",
        message: "Validation failed",
        details: customer.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue AsaasClient::ApiError => e
    render json: {
      error: "asaas_api_error",
      message: e.message,
      details: e.body
    }, status: :bad_gateway
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
