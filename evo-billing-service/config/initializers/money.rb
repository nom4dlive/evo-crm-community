MoneyRails.configure do |config|
  # Default currency: BRL — Ref: Spec C-03
  config.default_currency = :brl

  # Do NOT use floating point for currency arithmetic
  config.infinite_precision = false

  # Raise on currency mismatch to prevent silent conversion bugs
  config.raise_error_on_money_parsing = true
end
