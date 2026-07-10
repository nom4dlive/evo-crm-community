# Api::V1::ContactChargesController — REST endpoints for contact charges
# Ref: Spec P2-AC-02
#
# Tenant admins create charges against their customers (synced with Asaas).

class Api::V1::ContactChargesController < ApplicationController
  include AuthenticatedRequest

  before_action :require_admin!
  before_action :set_charge, only: [:show, :cancel, :retry_nfe]

  # GET /api/v1/contact_charges
  def index
    charges = ContactCharge.includes(:customer, :nfe_document)
                           .order(created_at: :desc)
                           .page(params[:page])
                           .per(params[:per_page] || 20)

    render json: {
      data: charges.as_json(include: {
        customer: { only: [:id, :name, :cpf_cnpj] },
        nfe_document: { only: [:id, :asaas_nfe_id, :nfe_number, :pdf_url, :xml_url, :nfe_error, :issued_at] }
      }),
      meta: pagination_meta(charges)
    }
  end

  # GET /api/v1/contact_charges/:id
  def show
    render json: {
      data: @charge.as_json(include: {
        customer: { only: [:id, :name, :cpf_cnpj] },
        nfe_document: { only: [:id, :asaas_nfe_id, :nfe_number, :pdf_url, :xml_url, :nfe_error, :issued_at] }
      })
    }
  end

  # POST /api/v1/contact_charges
  def create
    customer = Customer.find(charge_params[:customer_id])

    # Sync with Asaas
    billing_type_map = { "pix" => "PIX", "boleto" => "BOLETO", "credit_card" => "CREDIT_CARD" }
    asaas_response = asaas_client.create_charge(
      customer:    customer.asaas_customer_id,
      billingType: billing_type_map[charge_params[:billing_method]] || "PIX",
      value:       charge_params[:amount_cents].to_f / 100,
      dueDate:     charge_params[:due_date],
      description: charge_params[:description]
    )

    charge = ContactCharge.new(charge_params.merge(
      account_id:      Current.account_id,
      asaas_charge_id: asaas_response["id"],
      payment_link:    asaas_response["invoiceUrl"],
      status:          "pending"
    ))

    if charge.save
      render json: { data: charge }, status: :created
    else
      render json: {
        error: "unprocessable_entity",
        message: "Validation failed",
        details: charge.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue AsaasClient::ApiError => e
    render json: {
      error: "asaas_api_error",
      message: e.message,
      details: e.body
    }, status: :bad_gateway
  end

  # POST /api/v1/contact_charges/:id/cancel
  def cancel
    asaas_client.cancel_charge(@charge.asaas_charge_id)
    @charge.cancel!

    render json: { data: @charge }
  rescue AsaasClient::ApiError => e
    render json: {
      error: "asaas_api_error",
      message: e.message,
      details: e.body
    }, status: :bad_gateway
  end

  # POST /api/v1/contact_charges/:id/nfe/retry
  def retry_nfe
    if @charge.confirmed?
      nfe_doc = @charge.nfe_document
      nfe_doc&.update!(nfe_error: nil)

      NfeEmissionJob.perform_async(@charge.account_id, nil, @charge.id)
      render json: { data: { status: "queued", contact_charge_id: @charge.id } }
    else
      render json: { error: "unprocessable_entity", message: "Only confirmed charges can emit NF-e" },
             status: :unprocessable_entity
    end
  end

  private

  def set_charge
    @charge = ContactCharge.find(params[:id])
  end

  def charge_params
    params.require(:contact_charge).permit(
      :customer_id, :description, :amount_cents, :due_date, :billing_method
    )
  end

  def asaas_client
    @asaas_client ||= AsaasClient.new
  end
end
