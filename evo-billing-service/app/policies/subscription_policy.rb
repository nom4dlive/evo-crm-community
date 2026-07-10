# SubscriptionPolicy — Ref: Spec P1-AC-09, ADR-003 D4
# Tenant admin manages their own subscription
# Superadmin can manage any subscription

class SubscriptionPolicy < ApplicationPolicy
  def current? = admin?
  def show?    = admin?
  def create?  = admin?
  def update?  = admin?
  def destroy? = admin?
end
