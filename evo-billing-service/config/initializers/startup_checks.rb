# Startup guard: fail fast if required secrets are missing in non-test envs
# Ref: Spec C-02 — secrets must never be absent at boot
unless Rails.env.test?
  required_vars = %w[
    EVO_AUTH_JWT_PUBLIC_KEY
    INTERNAL_API_SECRET
  ]

  missing = required_vars.reject { |var| ENV[var].present? }

  if missing.any?
    raise <<~MSG
      [evo-billing-service] Missing required environment variables at startup:
        #{missing.join(', ')}
      Set them in .env or via Docker environment configuration.
    MSG
  end

  # Guard: ensure we are NOT pointed at the auth database (Spec P1-AC-02)
  db_url = ENV.fetch("DATABASE_URL", "")
  if db_url.include?("evogo_auth") || db_url.include?("evo_auth")
    raise "[evo-billing-service] DATABASE_URL must not point to the evo-auth database. " \
          "Use evo_billing_* databases only."
  end
end
