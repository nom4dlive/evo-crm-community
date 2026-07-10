# == Schema Information
# Table: asaas_webhook_events
# Global (not tenant-scoped) — idempotent event log
# Ref: Spec P2-AC-03

class AsaasWebhookEvent < ApplicationRecord
  validates :event_id,   presence: true, uniqueness: true
  validates :event_type, presence: true
  validates :payload,    presence: true

  scope :unprocessed, -> { where(processed: false) }
  scope :processed,   -> { where(processed: true) }

  def mark_processed!
    update!(processed: true, processed_at: Time.current)
  end

  def already_processed?
    processed?
  end
end
