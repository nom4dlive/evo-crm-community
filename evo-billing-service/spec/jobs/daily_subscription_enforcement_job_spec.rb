require "rails_helper"
require "webmock/rspec"

RSpec.describe DailySubscriptionEnforcementJob, type: :job do
  before do
    Current.account_id = nil # Job runs unscoped
    WebMock.enable!
  end

  after do
    Current.reset
    WebMock.reset!
  end

  let(:auth_url) { "http://evo-auth:3001" }
  let(:secret) { "test_internal_secret" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("EVO_AUTH_INTERNAL_URL", anything).and_return(auth_url)
    allow(ENV).to receive(:fetch).with("INTERNAL_API_SECRET", anything).and_return(secret)
  end

  describe "#perform" do
    it "suspends accounts whose grace period has expired" do
      # Create a past_due subscription with expired grace period
      plan = Plan.unscoped.create!(
        name: "Pro", price_monthly_cents: 9900, price_annual_cents: 99000,
        tier: "pro", annual_discount_pct: 0, active: true
      )
      Current.account_id = 42
      sub = Subscription.unscoped.create!(
        account_id: 42,
        plan: plan,
        billing_cycle: "monthly",
        status: "past_due",
        grace_period_ends_at: 2.days.ago
      )
      Current.account_id = nil

      stub_request(:post, "#{auth_url}/api/v1/internal/accounts/42/suspend")
        .with(headers: { "Authorization" => "Bearer #{secret}" })
        .to_return(status: 200, body: { status: "suspended" }.to_json)

      described_class.new.perform

      expect(sub.reload.status).to eq("canceled")
      expect(WebMock).to have_requested(:post, "#{auth_url}/api/v1/internal/accounts/42/suspend")
    end

    it "does not affect accounts still within grace period" do
      plan = Plan.unscoped.create!(
        name: "Basic", price_monthly_cents: 4900, price_annual_cents: 49000,
        tier: "starter", annual_discount_pct: 0, active: true
      )
      Current.account_id = 99
      sub = Subscription.unscoped.create!(
        account_id: 99,
        plan: plan,
        billing_cycle: "monthly",
        status: "past_due",
        grace_period_ends_at: 5.days.from_now
      )
      Current.account_id = nil

      described_class.new.perform

      expect(sub.reload.status).to eq("past_due")
    end

    it "does not affect active subscriptions" do
      plan = Plan.unscoped.create!(
        name: "Enterprise", price_monthly_cents: 19900, price_annual_cents: 199000,
        tier: "enterprise", annual_discount_pct: 0, active: true
      )
      Current.account_id = 77
      sub = Subscription.unscoped.create!(
        account_id: 77,
        plan: plan,
        billing_cycle: "monthly",
        status: "active"
      )
      Current.account_id = nil

      described_class.new.perform

      expect(sub.reload.status).to eq("active")
    end
  end
end
