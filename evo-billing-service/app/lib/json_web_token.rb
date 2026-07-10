# Decodes and validates JWT tokens issued by evo-auth-service (Doorkeeper JWT)
# Uses RS256 with the public key from ENV["EVO_AUTH_JWT_PUBLIC_KEY"]
# Ref: Spec P1-AC-07, ADR-003 D1

module JsonWebToken
  JWT_ALGORITHM = "RS256".freeze

  def self.decode(token)
    public_key_pem = ENV["EVO_AUTH_JWT_PUBLIC_KEY"]
    public_key_pem = nil if public_key_pem.to_s.strip.empty?

    if Rails.env.test? && public_key_pem.nil?
      return decode_test_token(token)
    elsif public_key_pem.nil?
      raise AuthenticationError, "EVO_AUTH_JWT_PUBLIC_KEY is not set"
    end

    public_key = OpenSSL::PKey::RSA.new(public_key_pem)

    JWT.decode(
      token,
      public_key,
      true,
      algorithms: [JWT_ALGORITHM]
    ).first
  rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
    raise AuthenticationError, "Invalid token: #{e.message}"
  rescue OpenSSL::PKey::RSAError => e
    raise AuthenticationError, "Invalid JWT public key configuration: #{e.message}"
  end

  # Test-only: decode without signature verification
  def self.decode_test_token(token)
    JWT.decode(token, nil, false).first
  rescue JWT::DecodeError => e
    raise AuthenticationError, "Invalid test token: #{e.message}"
  end
end
