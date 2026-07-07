#!/usr/bin/env bash
# TDD Test script for create-tenant.sh

TARGET_SCRIPT="bin/create-tenant.sh"

echo "=== Running TDD Test: Parameter Validation ==="

# Test case 1: No arguments should fail
bash "$TARGET_SCRIPT" >/dev/null 2>&1
EXIT_CODE=$?
if [ $EXIT_CODE -ne 1 ]; then
  echo "❌ Test Failed: Script did not exit with code 1 when no arguments were provided. Got code: $EXIT_CODE"
  exit 1
fi

# Test case 2: Partial arguments should fail
bash "$TARGET_SCRIPT" --slug "mytenant" >/dev/null 2>&1
EXIT_CODE=$?
if [ $EXIT_CODE -ne 1 ]; then
  echo "❌ Test Failed: Script did not exit with code 1 with partial arguments. Got code: $EXIT_CODE"
  exit 1
fi

echo "=== Running TDD Test: Dry-Run Command Generation (Red) ==="

# Test case 3: Valid arguments with --dry-run should generate correct rails command
OUTPUT=$(bash "$TARGET_SCRIPT" --slug "mytenant" --name "My Tenant" --email "admin@mytenant.com" --password "MyPassword123!" --dry-run)
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
  echo "❌ Test Failed: Script exited with non-zero code $EXIT_CODE on dry-run."
  exit 1
fi

if [[ ! "$OUTPUT" =~ "docker exec -i evo-auth bundle exec rails r" ]]; then
  echo "❌ Test Failed: Output does not contain expected docker exec rails runner command. Output was: $OUTPUT"
  exit 1
fi

if [[ ! "$OUTPUT" =~ "Account.find_or_create_by!" ]]; then
  echo "❌ Test Failed: Output does not contain Account.find_or_create_by! Rails code."
  exit 1
fi

echo "✅ Test Passed: Dry-run command generation verified successfully."
exit 0
