# DailySubscriptionEnforcementJob — Sidekiq cron job for dunning enforcement
# Ref: Spec P2-AC-04, ADR-003 D5
#
# Runs daily at 03:00 UTC. Responsibilities:
#   1. Find subscriptions past grace period
#   2. Call evo-auth S2S endpoint to suspend the account
#   3. Mark the subscription as canceled
#
# Grace period: 7 days after subscription enters past_due status
# (grace_period_ends_at is set when subscription transitions to past_due)

require "net/http"
require "json"
require "uri"

class DailySubscriptionEnforcementJob
  include Sidekiq::Job

  sidekiq_options queue: :billing, retry: 3

  def perform
    Rails.logger.info "[DailySubscriptionEnforcementJob] Starting enforcement run"

    suspended_count = 0
    error_count = 0

    # Find all subscriptions that are past_due and whose grace period has expired
    Subscription.unscoped
                .where(status: "past_due")
                .where("grace_period_ends_at < ?", Time.current)
                .find_each do |subscription|
      begin
        Rails.logger.info "[Enforcement] Processing account_id=#{subscription.account_id}, " \
                          "subscription_id=#{subscription.id}, " \
                          "grace_expired_at=#{subscription.grace_period_ends_at}"

        # 1. Call evo-auth to suspend the account
        suspend_account!(subscription.account_id)

        # 2. Cancel the subscription
        Current.account_id = subscription.account_id
        subscription.update!(status: "canceled", canceled_at: Time.current)

        suspended_count += 1
        Rails.logger.info "[Enforcement] Suspended account_id=#{subscription.account_id}"
      rescue StandardError => e
        error_count += 1
        Rails.logger.error "[Enforcement] Failed for account_id=#{subscription.account_id}: #{e.message}"
      ensure
        Current.account_id = nil
      end
    end

    Rails.logger.info "[DailySubscriptionEnforcementJob] Completed: " \
                      "suspended=#{suspended_count}, errors=#{error_count}"
  end

  private

  # Call evo-auth internal S2S endpoint to suspend an account
  def suspend_account!(account_id)
    auth_url = ENV.fetch("EVO_AUTH_INTERNAL_URL", "http://evo-auth:3001")
    secret   = ENV.fetch("INTERNAL_API_SECRET", "")

    uri = URI.parse("#{auth_url}/api/v1/internal/accounts/#{account_id}/suspend")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 10

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"]  = "application/json"
    request["Authorization"] = "Bearer #{secret}"

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "evo-auth suspend failed: #{response.code} — #{response.body}"
    end

    JSON.parse(response.body) rescue {}
  end
end
