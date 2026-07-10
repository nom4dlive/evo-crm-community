# Sidekiq configuration for evo-billing-service
# Ref: Spec P2-AC-04, ADR-003 D5

# Configure Sidekiq server
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/2") }

  # Load sidekiq-cron schedule
  config.on(:startup) do
    schedule = [
      {
        "name"  => "DailySubscriptionEnforcementJob",
        "cron"  => "0 3 * * *", # Daily at 03:00 UTC
        "class" => "DailySubscriptionEnforcementJob",
        "queue" => "billing"
      }
    ]

    Sidekiq::Cron::Job.load_from_array!(schedule)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/2") }
end
