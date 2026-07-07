puts "Running setup for Body Harmony Tenant..."

# Wait for DB connection
ActiveRecord::Base.connection

# Create Tenant/Account
account = Account.find_or_create_by!(slug: 'bodyharmony') do |a|
  a.name = 'Body Harmony'
  a.domain = 'bodyharmony.tech'
  a.status = 'active'
end

# Find roles
superadmin_role = Role.find_by(name: 'superadmin') || Role.first
admin_role = Role.find_by(name: 'admin') || Role.first

# Create superadmin
superadmin = User.find_or_initialize_by(email: 'superadmin@bodyharmony.tech')
superadmin.password = 'BodyHarmonyAdmin2026!'
superadmin.name = 'Super Admin'
superadmin.account = account
superadmin.save!

# Add superadmin role
UserRole.find_or_create_by!(user: superadmin, role: superadmin_role, account_id: account.id)

# Create support user
support = User.find_or_initialize_by(email: 'suporte@bodyharmony.tech')
support.password = 'SuporteBH2026!'
support.name = 'Suporte BH'
support.account = account
support.save!

# Add admin role to support
UserRole.find_or_create_by!(user: support, role: admin_role, account_id: account.id)

puts "✅ Users created successfully:"
puts "- #{superadmin.email}"
puts "- #{support.email}"
