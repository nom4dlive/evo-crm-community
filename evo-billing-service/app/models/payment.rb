# == Schema Information
# Table: payments
# Tenant-scoped by account_id — Ref: Spec P1-AC-06

class Payment < ApplicationRecord
  default_scope { where(account_id: Current.account_id) if Current.account_id.present? }
  tenant_scoped!

  monetize :amount_cents, as: :amount

  METHODS  = %w[pix boleto credit_card].freeze
  STATUSES = %w[pending confirmed failed refunded].freeze

  belongs_to :invoice, optional: true

  validates :account_id, presence: true
  validates :method,     inclusion: { in: METHODS }
  validates :status,     inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :asaas_payment_id, uniqueness: true, allow_nil: true

  scope :confirmed, -> { where(status: "confirmed") }
  scope :pending,   -> { where(status: "pending") }

  def confirmed? = status == "confirmed"
  def pending?   = status == "pending"
  def failed?    = status == "failed"
  def refunded?  = status == "refunded"
end
