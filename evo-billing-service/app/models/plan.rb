# == Schema Information
# Table: plans
# Global (not tenant-scoped) — visible to all authenticated requests

class Plan < ApplicationRecord
  # Money — Ref: Spec C-03, money-rails (integer cents only)
  monetize :price_monthly_cents, as: :price_monthly
  monetize :price_annual_cents,  as: :price_annual

  TIERS = %w[free starter pro enterprise].freeze
  BILLING_CYCLES = %w[monthly annual].freeze

  # Enums
  validates :tier, inclusion: { in: TIERS }

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :slug, presence: true, uniqueness: true,
                   format: { with: /\A[a-z0-9\-]+\z/, message: "must be lowercase letters, numbers, hyphens" }
  validates :price_monthly_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :price_annual_cents,  numericality: { greater_than_or_equal_to: 0 }
  validates :annual_discount_pct, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  # Associations
  has_many :subscriptions, dependent: :restrict_with_error

  # Scopes
  scope :active, -> { where(active: true) }

  # Callbacks
  before_validation :generate_slug, on: :create

  private

  def generate_slug
    return if slug.present?
    self.slug = name.to_s.parameterize
  end
end
