# InvoicePolicy — Ref: Spec P1-AC-10, ADR-003 D4
# Tenant admin: read own invoices
# Superadmin: read all invoices (cross-tenant scope handled in admin controller)

class InvoicePolicy < ApplicationPolicy
  def index? = admin?
  def show?  = admin?
end
