# == Schema Information
# Table: nfe_documents
# Tenant-scoped by account_id — Ref: Spec P4 (future), ADR-003 D2

class NfeDocument < ApplicationRecord
  default_scope { where(account_id: Current.account_id) if Current.account_id.present? }
  tenant_scoped!

  # Associations
  belongs_to :payment, optional: true
  belongs_to :contact_charge, optional: true

  # Validations
  validates :account_id,    presence: true
  validates :asaas_nfe_id,  presence: true, uniqueness: true
end
