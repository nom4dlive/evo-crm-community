class HealthController < ApplicationController
  # No auth required — Ref: Spec P1-AC-11
  def show
    render json: {
      status: "ok",
      service: "evo-billing-service",
      timestamp: Time.current.iso8601
    }, status: :ok
  end
end
