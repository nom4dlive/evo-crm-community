module AuthHelpers
  def auth_headers_for(account_id:, role: "admin", user_id: 1)
    token = JWT.encode(
      {
        sub: user_id.to_s,
        user_id: user_id,
        account_id: account_id,
        role: role,
        exp: 1.hour.from_now.to_i
      },
      nil,
      "none"  # No signature in test env — JsonWebToken#decode_test_token handles this
    )
    { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
  end

  def superadmin_headers(account_id: 0)
    auth_headers_for(account_id: account_id, role: "superadmin")
  end
end
