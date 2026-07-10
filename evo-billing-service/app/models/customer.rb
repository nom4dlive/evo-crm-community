# == Schema Information
# Table: customers
# Tenant-scoped by account_id — Ref: Spec P2-AC-01, ADR-003 D2

class Customer < ApplicationRecord
  default_scope { where(account_id: Current.account_id) if Current.account_id.present? }
  tenant_scoped!

  # Associations
  has_many :contact_charges, dependent: :destroy

  # Validations
  validates :account_id,        presence: true
  validates :contact_id,        presence: true
  validates :asaas_customer_id, presence: true, uniqueness: true
  validates :cpf_cnpj,          presence: true

  # Scopes
  scope :by_contact, ->(contact_id) { where(contact_id: contact_id) }
end
