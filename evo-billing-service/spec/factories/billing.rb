FactoryBot.define do
  factory :plan do
    sequence(:name) { |n| "Plan #{n}" }
    sequence(:slug) { |n| "plan-#{n}" }
    tier { "starter" }
    price_monthly_cents { 4990 }
    price_annual_cents { 49900 }
    annual_discount_pct { 17 }
    limit_instances { 3 }
    limit_agents { 10 }
    limit_messages_per_month { 10_000 }
    active { true }
  end

  factory :subscription do
    account_id { 1 }
    association :plan
    billing_cycle { "monthly" }
    status { "trial" }
    trial_ends_at { 14.days.from_now }
    current_period_start { Date.current }
    current_period_end { 1.month.from_now.to_date }
  end

  factory :invoice do
    account_id { 1 }
    association :subscription
    status { "open" }
    subtotal_cents { 4990 }
    total_cents { 4990 }
    currency { "BRL" }
    due_date { 7.days.from_now.to_date }
  end

  factory :invoice_item do
    association :invoice
    description { "Monthly plan fee" }
    quantity { 1 }
    unit_price_cents { 4990 }
    total_cents { 4990 }
  end

  factory :payment do
    account_id { 1 }
    association :invoice
    add_attribute(:method) { "pix" }
    status { "pending" }
    amount_cents { 4990 }
  end
end
