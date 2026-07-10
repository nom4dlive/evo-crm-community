class ApplicationController < ActionController::API
  include Pundit::Authorization

  # LESSON: rescue_from StandardError MUST be at the top (Rails processes in reverse order)
  # Ref: Global Lessons — rails-exceptions [Severity: HIGH]
  rescue_from StandardError, with: :render_internal_error
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable
  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden
  rescue_from TenantContextMissing, with: :render_internal_error

  private

  def render_not_found(e)
    render json: { error: "not_found", message: e.message }, status: :not_found
  end

  def render_unprocessable(e)
    render json: {
      error: "unprocessable_entity",
      message: e.message,
      details: e.record&.errors&.full_messages
    }, status: :unprocessable_entity
  end

  def render_forbidden(e)
    render json: { error: "forbidden", message: "You are not authorized to perform this action" },
           status: :forbidden
  end

  def render_internal_error(e)
    Rails.logger.error "[ApplicationController] #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n") if e.backtrace
    render json: { error: "internal_server_error", message: "An unexpected error occurred" },
           status: :internal_server_error
  end

  def pagination_meta(collection)
    {
      page: collection.current_page,
      per_page: collection.limit_value,
      total: collection.total_count,
      total_pages: collection.total_pages
    }
  end
end
