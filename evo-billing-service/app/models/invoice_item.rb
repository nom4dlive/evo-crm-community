class InvoiceItem < ApplicationRecord
  monetize :unit_price_cents, as: :unit_price
  monetize :total_cents,      as: :total

  belongs_to :invoice

  validates :description, presence: true, length: { maximum: 255 }
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }

  before_validation :compute_total

  private

  def compute_total
    self.total_cents = (unit_price_cents.to_i * quantity.to_i)
  end
end
