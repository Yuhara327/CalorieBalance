#!/bin/zsh
set -euo pipefail

script_directory=${0:A:h}
repository_directory=${script_directory:h}
test_output_directory=/tmp/CalorieBalanceSubscriptionPolicyTests

mkdir -p "$test_output_directory/ModuleCache"

xcrun swiftc \
    -module-cache-path "$test_output_directory/ModuleCache" \
    "$repository_directory/CalorieBalance/Services/SubscriptionEntitlementPolicy.swift" \
    "$repository_directory/Tests/SubscriptionEntitlementPolicyChecks.swift" \
    -o "$test_output_directory/SubscriptionEntitlementPolicyChecks"

"$test_output_directory/SubscriptionEntitlementPolicyChecks"
