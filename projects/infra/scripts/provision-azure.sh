#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/environment-common.sh"

[[ $# -eq 1 ]] || { echo "usage: $0 <environment>" >&2; exit 1; }
require_azure_command
require_environment
load_azure_context

ensure_resource_group
resolve_acr_name

ensure_identity
APPLICATION_ID="$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query clientId -o tsv)"
PRINCIPAL_ID="$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query principalId -o tsv)"
IDENTITY_ID="$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)"

ensure_app_service_plan
ensure_web_app
ensure_web_app_identity "$IDENTITY_ID"

acr_id="$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)"
rg_id="$(az group show --name "$RESOURCE_GROUP" --query id -o tsv)"
ensure_role_assignment "$PRINCIPAL_ID" AcrPush "$acr_id"
ensure_role_assignment "$PRINCIPAL_ID" AcrPull "$acr_id"
ensure_role_assignment "$PRINCIPAL_ID" "Website Contributor" "$rg_id"

for subject in \
  "repo:${GITHUB_OWNER}/${PLATFORM_REPOSITORY}:environment:${ENVIRONMENT}" \
  "repo:${GITHUB_OWNER}@${GITHUB_OWNER_ID}/${PLATFORM_REPOSITORY}@${PLATFORM_REPOSITORY_ID}:environment:${ENVIRONMENT}"; do
  name="$FIC_NAME"
  [[ "$subject" == repo:*@* ]] && name="$NUMERIC_FIC_NAME"
  ensure_federated_credential "$name" "$subject"
done

write_context
echo "Provisioned Azure resources for $ENVIRONMENT: $RESOURCE_GROUP, $ACR_LOGIN_SERVER, $APP_NAME"
