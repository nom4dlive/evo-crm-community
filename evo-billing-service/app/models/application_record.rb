# Raised when a tenant-scoped query is attempted without an account_id context
class TenantContextMissing < StandardError
  def initialize(model_name = "unknown")
    super("TenantContextMissing: #{model_name} requires Current.account_id to be set. " \
          "Ensure AuthenticatedRequest concern is applied to the controller.")
  end
end

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Enforce that all tenant-scoped subclasses have an account_id context.
  # Call `tenant_scoped!` in each model that requires isolation.
  def self.tenant_scoped!
    before_validation :assert_tenant_context!
  end

  private

  def assert_tenant_context!
    return if self.class.column_names.exclude?("account_id")
    raise TenantContextMissing, self.class.name if Current.account_id.nil?
  end
end
