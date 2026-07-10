MoneyRails.configure do |config|
  # Default currency: BRL — Ref: Spec C-03
  config.default_currency = :brl

  # Raise on currency mismatch to prevent silent conversion bugs
  config.raise_error_on_money_parsing = true
end
