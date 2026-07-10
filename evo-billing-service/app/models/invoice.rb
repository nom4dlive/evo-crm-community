# == Schema Information
# Table: invoices
# Tenant-scoped by account_id — Ref: Spec P1-AC-06

class Invoice < ApplicationRecord
  default_scope { where(account_id: Current.account_id) if Current.account_id.present? }
  tenant_scoped!

  monetize :subtotal_cents, as: :subtotal
  monetize :total_cents,    as: :total

  STATUSES = %w[draft open paid void].freeze

  belongs_to :subscription, optional: true
  has_many :invoice_items, dependent: :destroy
  has_many :payments, dependent: :nullify

  validates :account_id, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :currency, inclusion: { in: %w[BRL] }

  scope :paid,  -> { where(status: "paid") }
  scope :open,  -> { where(status: "open") }

  def paid?  = status == "paid"
  def open?  = status == "open"
  def draft? = status == "draft"
  def void?  = status == "void"
end
