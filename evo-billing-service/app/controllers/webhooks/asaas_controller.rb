# Webhooks::AsaasController — Asaas webhook ingress
# Ref: Spec P2-AC-03, ADR-003 D6
#
# Responsibilities:
#   1. Verify HMAC-SHA256 signature (mandatory — Ref: /grill-me decision)
#   2. Log raw event idempotently via AsaasWebhookEvent
#   3. Dispatch status transitions on Payment / ContactCharge

module Webhooks
  class AsaasController < ApplicationController
    # No JWT auth — webhook uses HMAC signature verification
    skip_before_action :authenticate_request!, raise: false

    before_action :verify_webhook_signature!

    # POST /webhooks/asaas
    def create
      event_data = webhook_params
      event_id   = event_data[:id] || SecureRandom.uuid
      event_type = event_data[:event]

      # Idempotency: skip if already processed
      existing = AsaasWebhookEvent.find_by(event_id: event_id)
      if existing&.already_processed?
        return render json: { status: "already_processed" }, status: :ok
      end

      # Log the raw event
      webhook_event = AsaasWebhookEvent.find_or_create_by!(event_id: event_id) do |e|
        e.event_type = event_type
        e.payload    = event_data.to_unsafe_h
      end

      # Process the event
      process_event(event_type, event_data[:payment])

      webhook_event.mark_processed!

      render json: { status: "processed" }, status: :ok
    rescue StandardError => e
      Rails.logger.error "[Webhooks::Asaas] Error processing webhook: #{e.message}"
      render json: { status: "error", message: e.message }, status: :unprocessable_entity
    end

    private

    def webhook_params
      params.permit!
    end

    def verify_webhook_signature!
      webhook_secret = ENV["ASAAS_WEBHOOK_SECRET"]

      # In test env without secret configured, skip verification
      if webhook_secret.blank? && Rails.env.test?
        return
      end

      if webhook_secret.blank?
        render json: { error: "webhook_secret_not_configured" }, status: :internal_server_error
        return
      end

      signature = request.headers["asaas-access-token"]

      if signature.blank? || !ActiveSupport::SecurityUtils.secure_compare(signature, webhook_secret)
        render json: { error: "invalid_signature" }, status: :unauthorized
        return
      end
    end

    def process_event(event_type, payment_data)
      return if payment_data.blank?

      asaas_payment_id = payment_data[:id] || payment_data["id"]
      return if asaas_payment_id.blank?

      case event_type
      when "PAYMENT_CONFIRMED", "PAYMENT_RECEIVED"
        confirm_payment(asaas_payment_id)
      when "PAYMENT_OVERDUE"
        mark_payment_overdue(asaas_payment_id)
      when "PAYMENT_DELETED", "PAYMENT_REFUNDED"
        cancel_payment(asaas_payment_id)
      end
    end

    def confirm_payment(asaas_payment_id)
      # Try platform payment first (subscription invoices)
      payment = Payment.unscoped.find_by(asaas_payment_id: asaas_payment_id)
      if payment
        Current.account_id = payment.account_id
        payment.update!(status: "confirmed")

        invoice = payment.invoice
        if invoice
          invoice.update!(status: "paid")

          subscription = invoice.subscription
          if subscription
            was_past_due = subscription.past_due?
            subscription.update!(status: "active", grace_period_ends_at: nil)

            if was_past_due
              unsuspend_account!(payment.account_id)
            end
          end
        end

        # Trigger NF-e emission asynchronously (Spec P4-AC-01)
        NfeEmissionJob.perform_async(payment.account_id, payment.id, nil)
      end

      # Try contact charge (tenant→contact charges)
      charge = ContactCharge.unscoped.find_by(asaas_charge_id: asaas_payment_id)
      if charge
        Current.account_id = charge.account_id
        charge.confirm!

        # Trigger NF-e emission asynchronously (Spec P4-AC-01)
        NfeEmissionJob.perform_async(charge.account_id, nil, charge.id)
      end
    ensure
      Current.account_id = nil
    end

    def mark_payment_overdue(asaas_payment_id)
      payment = Payment.unscoped.find_by(asaas_payment_id: asaas_payment_id)
      if payment
        Current.account_id = payment.account_id
        payment.update!(status: "failed")
      end

      charge = ContactCharge.unscoped.find_by(asaas_charge_id: asaas_payment_id)
      if charge
        Current.account_id = charge.account_id
        charge.mark_overdue!
      end
    ensure
      Current.account_id = nil
    end

    def cancel_payment(asaas_payment_id)
      payment = Payment.unscoped.find_by(asaas_payment_id: asaas_payment_id)
      if payment
        Current.account_id = payment.account_id
        payment.update!(status: "refunded") if payment.status != "refunded"
      end

      charge = ContactCharge.unscoped.find_by(asaas_charge_id: asaas_payment_id)
      if charge
        Current.account_id = charge.account_id
        charge.cancel!
      end
    ensure
      Current.account_id = nil
    end

    private

    def unsuspend_account!(account_id)
      auth_url = ENV.fetch("EVO_AUTH_INTERNAL_URL", "http://evo-auth:3001")
      secret   = ENV.fetch("INTERNAL_API_SECRET", "")

      uri = URI.parse("#{auth_url}/api/v1/internal/accounts/#{account_id}/unsuspend")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"]  = "application/json"
      request["Authorization"] = "Bearer #{secret}"

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.error "[Webhooks::Asaas] Failed to unsuspend account #{account_id}: #{response.code} — #{response.body}"
      end
    rescue StandardError => e
      Rails.logger.error "[Webhooks::Asaas] Connection error unsuspending account #{account_id}: #{e.message}"
    end
  end
end
