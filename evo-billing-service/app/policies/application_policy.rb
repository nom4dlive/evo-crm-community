class ApplicationPolicy
  attr_reader :user_context, :record

  # user_context is a hash: { account_id:, user_id:, role: }
  def initialize(user_context, record)
    @user_context = user_context
    @record = record
  end

  def superadmin?
    user_context[:role] == "superadmin"
  end

  def admin?
    user_context[:role].in?(%w[superadmin admin])
  end

  def index?   = false
  def show?    = false
  def create?  = false
  def update?  = false
  def destroy? = false
end
