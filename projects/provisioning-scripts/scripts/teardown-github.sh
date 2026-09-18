#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/environment-common.sh"

[[ $# -eq 1 ]] || { echo "usage: $0 <environment>" >&2; exit 1; }
require_github_command
require_environment
load_resource_context
load_github_context

echo "This permanently deletes GitHub environment '$ENVIRONMENT' from ${GITHUB_OWNER}/${PLATFORM_REPOSITORY}."
read -r -p "Type '$ENVIRONMENT' to continue: " confirmation
[[ "$confirmation" == "$ENVIRONMENT" ]] ||
  { echo "error: confirmation did not match" >&2; exit 1; }

gh api --method DELETE "repos/${GITHUB_OWNER}/${PLATFORM_REPOSITORY}/environments/${ENVIRONMENT}"
echo "GitHub teardown completed for $ENVIRONMENT."
