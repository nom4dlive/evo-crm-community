# == Schema Information
# Table: contact_charges
# Tenant-scoped by account_id — Ref: Spec P2-AC-02, ADR-003 D2

class ContactCharge < ApplicationRecord
  default_scope { where(account_id: Current.account_id) if Current.account_id.present? }
  tenant_scoped!

  BILLING_METHODS = %w[pix boleto credit_card].freeze
  STATUSES        = %w[pending confirmed overdue canceled].freeze

  # Associations
  belongs_to :customer
  has_one :nfe_document, dependent: :nullify

  # Monetize
  monetize :amount_cents, as: :amount

  # Validations
  validates :account_id,      presence: true
  validates :description,     presence: true
  validates :amount_cents,    numericality: { greater_than: 0 }
  validates :due_date,        presence: true
  validates :billing_method,  inclusion: { in: BILLING_METHODS }
  validates :status,          inclusion: { in: STATUSES }
  validates :asaas_charge_id, presence: true, uniqueness: true

  # Scopes
  scope :pending,   -> { where(status: "pending") }
  scope :confirmed, -> { where(status: "confirmed") }
  scope :overdue,   -> { where(status: "overdue") }

  # State helpers
  def pending?   = status == "pending"
  def confirmed? = status == "confirmed"
  def overdue?   = status == "overdue"
  def canceled?  = status == "canceled"

  def confirm!
    update!(status: "confirmed")
  end

  def mark_overdue!
    update!(status: "overdue")
  end

  def cancel!
    update!(status: "canceled")
  end
end
