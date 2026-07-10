class NfeEmissionJob
  include Sidekiq::Job
  queue_as :billing

  def perform(account_id, payment_id, contact_charge_id, attempt = 1)
    Current.account_id = account_id

    target = if payment_id.present?
               Payment.unscoped.find_by(id: payment_id)
             elsif contact_charge_id.present?
               ContactCharge.unscoped.find_by(id: contact_charge_id)
             end

    return if target.nil?
    return unless target.confirmed?

    nfe_doc = target.nfe_document
    return if nfe_doc.present? && nfe_doc.pdf_url.present?

    nfe_doc ||= if payment_id.present?
                  NfeDocument.new(account_id: account_id, payment_id: payment_id)
                else
                  NfeDocument.new(account_id: account_id, contact_charge_id: contact_charge_id)
                end

    asaas_payment_id = payment_id.present? ? target.asaas_payment_id : target.asaas_charge_id
    return if asaas_payment_id.blank?

    begin
      description = if target.respond_to?(:description)
                      target.description
                    elsif target.respond_to?(:invoice) && target.invoice
                      target.invoice.subscription&.plan&.name || "Mensalidade do Sistema CRM"
                    else
                      "Prestação de Serviço de CRM"
                    end

      client = AsaasClient.new
      response = client.create_nfe(asaas_payment_id, {
        serviceDescription: description.presence || "Prestação de Serviço de CRM"
      })

      nfe_doc.assign_attributes(
        asaas_nfe_id: response["id"],
        nfe_number:   response["number"],
        pdf_url:      response["pdfUrl"],
        xml_url:      response["xmlUrl"],
        nfe_error:    nil,
        issued_at:    Time.current
      )
      nfe_doc.save!
    rescue AsaasClient::ApiError => e
      Rails.logger.error "[NfeEmissionJob] Asaas API error: #{e.message} (Attempt #{attempt}/3)"
      
      placeholder_id = "failed_#{payment_id.present? ? 'pay_' + payment_id.to_s : 'charge_' + contact_charge_id.to_s}"
      nfe_doc.asaas_nfe_id ||= placeholder_id
      nfe_doc.nfe_error = e.message
      nfe_doc.save!

      if attempt < 3 && !validation_error?(e)
        NfeEmissionJob.perform_in(24.hours, account_id, payment_id, contact_charge_id, attempt + 1)
      end
    rescue StandardError => e
      Rails.logger.error "[NfeEmissionJob] Unexpected error: #{e.message} (Attempt #{attempt}/3)"
      
      placeholder_id = "failed_#{payment_id.present? ? 'pay_' + payment_id.to_s : 'charge_' + contact_charge_id.to_s}"
      nfe_doc.asaas_nfe_id ||= placeholder_id
      nfe_doc.nfe_error = e.message
      nfe_doc.save!

      if attempt < 3
        NfeEmissionJob.perform_in(24.hours, account_id, payment_id, contact_charge_id, attempt + 1)
      end
    ensure
      Current.account_id = nil
    end
  end

  private

  def validation_error?(error)
    error.status == 400 || error.status == 422
  end
end
