#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/environment-common.sh"

[[ $# -eq 1 ]] || { echo "usage: $0 <environment>" >&2; exit 1; }
require_github_command
require_environment
load_context_file "$1"
load_github_context
set_platform_environment
echo "Provisioned GitHub Environment '$ENVIRONMENT' in ${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}"
