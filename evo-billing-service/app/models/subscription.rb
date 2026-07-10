# == Schema Information
# Table: subscriptions
# Tenant-scoped by account_id — Ref: Spec P1-AC-06, ADR-003 D2

class Subscription < ApplicationRecord
  # Tenant isolation — Ref: ADR-002 pattern, Spec P1-AC-06
  default_scope { where(account_id: Current.account_id) if Current.account_id.present? }
  tenant_scoped!

  STATUSES = %w[trial active past_due canceled].freeze
  BILLING_CYCLES = %w[monthly annual].freeze

  # Associations
  belongs_to :plan

  # Validations
  validates :account_id, presence: true
  validates :billing_cycle, inclusion: { in: BILLING_CYCLES }
  validates :status, inclusion: { in: STATUSES }
  validate :only_one_active_subscription, on: :create

  # Scopes
  scope :active,   -> { where(status: "active") }
  scope :trial,    -> { where(status: "trial") }
  scope :past_due, -> { where(status: "past_due") }
  scope :grace_expired, -> { past_due.where("grace_period_ends_at < ?", Time.current) }

  # State helpers
  def active?   = status == "active"
  def trial?    = status == "trial"
  def past_due? = status == "past_due"
  def canceled? = status == "canceled"

  def cancel!
    update!(status: "canceled", canceled_at: Time.current)
  end

  private

  def only_one_active_subscription
    return unless account_id.present?

    existing = Subscription.unscoped
                            .where(account_id: account_id)
                            .where(status: %w[trial active past_due])
                            .exists?
    errors.add(:base, "An active subscription already exists for this account") if existing
  end
end
