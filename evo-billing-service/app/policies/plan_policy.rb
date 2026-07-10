# PlanPolicy — Ref: Spec P1-AC-08, ADR-003 D4
# GET /api/v1/plans — public (no auth required, handled in controller)
# POST/PATCH/DELETE — superadmin only

class PlanPolicy < ApplicationPolicy
  def index?   = true   # public (auth not required for GET, but policy is consistent)
  def show?    = true   # public
  def create?  = superadmin?
  def update?  = superadmin?
  def destroy? = superadmin?  # soft-delete via active=false
end
