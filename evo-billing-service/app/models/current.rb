class Current < ActiveSupport::CurrentAttributes
  attribute :account_id, :user_id, :role

  def superadmin?
    role == "superadmin"
  end

  def admin?
    role.in?(%w[superadmin admin])
  end
end
