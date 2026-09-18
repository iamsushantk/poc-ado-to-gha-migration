#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/environment-common.sh"

[[ $# -eq 1 ]] || { echo "usage: $0 <environment>" >&2; exit 1; }
require_azure_command
require_environment
load_resource_context
require_github_command
load_github_context

echo "This permanently deletes Azure resource group '$RESOURCE_GROUP'."
read -r -p "Type '$ENVIRONMENT' to continue: " confirmation
[[ "$confirmation" == "$ENVIRONMENT" ]] ||
  { echo "error: confirmation did not match" >&2; exit 1; }

az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo "Azure teardown started for $ENVIRONMENT."
