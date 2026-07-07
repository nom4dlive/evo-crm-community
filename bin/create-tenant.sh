#!/usr/bin/env bash
# create-tenant.sh — Interactive / CLI Tenant Creator helper

# Default values
SLUG=""
NAME=""
EMAIL=""
PASSWORD=""
DRY_RUN=0

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --slug) SLUG="$2"; shift ;;
    --name) NAME="$2"; shift ;;
    --email) EMAIL="$2"; shift ;;
    --password) PASSWORD="$2"; shift ;;
    --dry-run) DRY_RUN=1 ;;
    *) echo "Unknown parameter passed: $1"; exit 1 ;;
  esac
  shift
done

# Check if interactive (running in a TTY)
INTERACTIVE=0
if [ -t 0 ]; then
  INTERACTIVE=1
fi

# Prompt helper
prompt_field() {
  local field_var_name=$1
  local prompt_msg=$2
  local is_password=$3
  local val="${!field_var_name}"

  while [ -z "$val" ]; do
    if [ "$INTERACTIVE" -eq 1 ]; then
      if [ "$is_password" -eq 1 ]; then
        read -s -p "$prompt_msg: " val
        echo ""
      else
        read -p "$prompt_msg: " val
      fi
    else
      echo "Error: Required parameter --$field_var_name is missing." >&2
      exit 1
    fi
  done
  eval "$field_var_name=\"$val\""
}

prompt_field "SLUG" "Enter Tenant Slug (e.g. bodyharmony)" 0
prompt_field "NAME" "Enter Tenant Display Name (e.g. Body Harmony)" 0
prompt_field "EMAIL" "Enter Admin Email (e.g. admin@bodyharmony.tech)" 0
prompt_field "PASSWORD" "Enter Admin Password" 1

# Generate the Ruby script to run in Rails
RUBY_SCRIPT=$(cat <<EOF
puts "Running setup for Tenant: ${NAME}..."
ActiveRecord::Base.connection
account = Account.find_or_create_by!(slug: '${SLUG}') do |a|
  a.name = '${NAME}'
  a.domain = '${SLUG}.tech'
  a.status = 'active'
end
admin_role = Role.find_by(name: 'admin') || Role.first
user = User.find_or_initialize_by(email: '${EMAIL}')
user.password = '${PASSWORD}'
user.name = '${NAME} Admin'
user.account = account
user.save!
UserRole.find_or_create_by!(user: user, role: admin_role, account_id: account.id)
puts "✅ Tenant and User configured successfully!"
EOF
)

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry run: would run: docker exec -i evo-crm bundle exec rails r -"
  echo "--- Ruby Script to execute ---"
  echo "$RUBY_SCRIPT"
  echo "------------------------------"
  exit 0
fi

# Execution
echo "Executing provisioning script inside evo-crm container..."
echo "$RUBY_SCRIPT" | docker exec -i evo-crm bundle exec rails r -
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ Error: Rails runner exited with code $EXIT_CODE" >&2
  exit $EXIT_CODE
fi

echo "✅ Provisioning completed successfully!"
exit 0
