#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

ENVIRONMENT="${1:-}"
RESOURCE_PREFIX="${RESOURCE_PREFIX:-poc-subscription}"
AZURE_LOCATION="${AZURE_LOCATION:-australiaeast}"
ACR_SKU="${ACR_SKU:-Basic}"
APP_SERVICE_SKU="${APP_SERVICE_SKU:-B1}"
GITHUB_OWNER="${GITHUB_OWNER:-}"
PLATFORM_REPOSITORY="${PLATFORM_REPOSITORY:-}"
GITHUB_OWNER_ID="${GITHUB_OWNER_ID:-132103049}"
PLATFORM_REPOSITORY_ID="${PLATFORM_REPOSITORY_ID:-1375463783}"
PLACEHOLDER_IMAGE="${PLACEHOLDER_IMAGE:-mcr.microsoft.com/appsvc/staticsite:latest}"

require_azure_command() {
  command -v az >/dev/null || { echo "error: Azure CLI (az) is required" >&2; exit 1; }
}

require_github_command() {
  command -v gh >/dev/null || { echo "error: GitHub CLI (gh) is required" >&2; exit 1; }
}

load_github_context() {
  if [[ -z "$GITHUB_OWNER" || -z "$PLATFORM_REPOSITORY" ]]; then
    local repository
    repository="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
    GITHUB_OWNER="${repository%%/*}"
    PLATFORM_REPOSITORY="${repository#*/}"
  fi
  [[ -n "$GITHUB_OWNER" && -n "$PLATFORM_REPOSITORY" ]] ||
    { echo "error: GitHub owner and repository could not be determined" >&2; exit 1; }
}

require_environment() {
  [[ "$ENVIRONMENT" =~ ^[a-z][a-z0-9-]*$ ]] ||
    { echo "error: use a lowercase environment name such as uat" >&2; exit 1; }
}

load_resource_context() {
  RESOURCE_GROUP="rg-${RESOURCE_PREFIX}-${ENVIRONMENT}"
  ACR_NAME="acr$(tr -d '-' <<< "$RESOURCE_PREFIX")${ENVIRONMENT}$(printf '%04d' "$(( $(od -An -N2 -tu2 /dev/urandom) % 10000 ))")"
  ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"
  PLAN_NAME="plan-${RESOURCE_PREFIX}-${ENVIRONMENT}"
  APP_NAME="app-${RESOURCE_PREFIX}-${ENVIRONMENT}"
  IDENTITY_NAME="id-${RESOURCE_PREFIX}-${ENVIRONMENT}"
  FIC_NAME="fic-${RESOURCE_PREFIX}-${ENVIRONMENT}"
  NUMERIC_FIC_NAME="${FIC_NAME}-numeric-subject"
}

load_azure_context() {
  load_resource_context
  load_github_context
  SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
  TENANT_ID="$(az account show --query tenantId -o tsv)"
  APPLICATION_ID="$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query clientId -o tsv)"
}

write_context() {
  local context_file="${PROVISIONING_CONTEXT_FILE:-$SCRIPT_DIR/.provisioning-context}"
  umask 077
  cat > "$context_file" <<EOF
ENVIRONMENT=$ENVIRONMENT
RESOURCE_GROUP=$RESOURCE_GROUP
ACR_LOGIN_SERVER=$ACR_LOGIN_SERVER
APP_NAME=$APP_NAME
APPLICATION_ID=$APPLICATION_ID
TENANT_ID=$TENANT_ID
SUBSCRIPTION_ID=$SUBSCRIPTION_ID
GITHUB_OWNER=$GITHUB_OWNER
PLATFORM_REPOSITORY=$PLATFORM_REPOSITORY
EOF
  echo "Wrote provisioning context to $context_file"
}

load_context_file() {
  local context_file="${PROVISIONING_CONTEXT_FILE:-$SCRIPT_DIR/.provisioning-context}"
  [[ -f "$context_file" ]] ||
    { echo "error: Azure context file not found: $context_file; run provision-azure.sh first" >&2; exit 1; }
  # shellcheck disable=SC1090
  source "$context_file"
  [[ "${ENVIRONMENT:-}" == "$1" ]] ||
    { echo "error: context environment does not match '$1'" >&2; exit 1; }
}

set_platform_environment() {
  gh api --method PUT "repos/${GITHUB_OWNER}/${PLATFORM_REPOSITORY}/environments/${ENVIRONMENT}" >/dev/null
  printf '%s' "$APPLICATION_ID" |
    gh secret set AZURE_CLIENT_ID --repo "${GITHUB_OWNER}/${PLATFORM_REPOSITORY}" --env "$ENVIRONMENT"
  printf '%s' "$TENANT_ID" |
    gh secret set AZURE_TENANT_ID --repo "${GITHUB_OWNER}/${PLATFORM_REPOSITORY}" --env "$ENVIRONMENT"
  printf '%s' "$SUBSCRIPTION_ID" |
    gh secret set AZURE_SUBSCRIPTION_ID --repo "${GITHUB_OWNER}/${PLATFORM_REPOSITORY}" --env "$ENVIRONMENT"
  gh variable set ACR_LOGIN_SERVER --repo "${GITHUB_OWNER}/${PLATFORM_REPOSITORY}" --env "$ENVIRONMENT" --body "$ACR_LOGIN_SERVER"
  gh variable set RESOURCE_GROUP --repo "${GITHUB_OWNER}/${PLATFORM_REPOSITORY}" --env "$ENVIRONMENT" --body "$RESOURCE_GROUP"
  gh variable set APP_SERVICE_NAME --repo "${GITHUB_OWNER}/${PLATFORM_REPOSITORY}" --env "$ENVIRONMENT" --body "$APP_NAME"
}