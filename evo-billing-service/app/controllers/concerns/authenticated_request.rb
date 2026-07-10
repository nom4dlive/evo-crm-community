module AuthenticatedRequest
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request!
  end

  private

  def authenticate_request!
    token = extract_token_from_header
    raise AuthenticationError, "Missing authorization token" if token.nil?

    payload = JsonWebToken.decode(token)

    # Set thread-local context — Ref: Spec P1-AC-07, ADR-003 D1
    Current.user_id    = payload["sub"] || payload["user_id"]
    Current.account_id = (payload["account_id"] || payload["aid"])&.to_i
    Current.role       = payload["role"] || "agent"

    raise AuthenticationError, "Token missing account_id claim" if Current.account_id.nil?
  rescue AuthenticationError => e
    render json: { error: "unauthorized", message: e.message }, status: :unauthorized
  end

  def extract_token_from_header
    header = request.headers["Authorization"]
    return nil unless header&.start_with?("Bearer ")
    header.sub("Bearer ", "")
  end

  def require_superadmin!
    raise AuthorizationError, "Superadmin access required" unless Current.superadmin?
  rescue AuthorizationError => e
    render json: { error: "forbidden", message: e.message }, status: :forbidden
  end

  def require_admin!
    raise AuthorizationError, "Admin access required" unless Current.admin?
  rescue AuthorizationError => e
    render json: { error: "forbidden", message: e.message }, status: :forbidden
  end
end
