#!/usr/bin/env bash

# One-time setup: infra-setup.yml and infra-teardown.yml need to log in to Azure via OIDC
# *before* any per-environment identity exists (provision-azure.sh creates that per-environment
# identity, and provision-github.sh stores its credentials as environment secrets). This script
# creates a separate, standing "bootstrap" identity trusted for those two workflows specifically,
# and stores its credentials as repository-level secrets (not tied to any GitHub Environment).
#
# Run this once, locally, authenticated with an Azure account that can create role assignments
# (e.g. Owner) at the subscription scope:
#   ./scripts/bootstrap-azure.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/environment-common.sh"

require_azure_command
require_github_command
load_github_context

BOOTSTRAP_RESOURCE_GROUP="${BOOTSTRAP_RESOURCE_GROUP:-rg-${RESOURCE_PREFIX}-bootstrap}"
BOOTSTRAP_BRANCH="${BOOTSTRAP_BRANCH:-main}"

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
subscription_scope="/subscriptions/${SUBSCRIPTION_ID}"

if az group show --name "$BOOTSTRAP_RESOURCE_GROUP" >/dev/null 2>&1; then
  echo "Bootstrap resource group '$BOOTSTRAP_RESOURCE_GROUP' already exists; skipping creation."
else
  az group create --name "$BOOTSTRAP_RESOURCE_GROUP" --location "$AZURE_LOCATION" \
    --tags purpose=infra-bootstrap >/dev/null
  echo "Created bootstrap resource group '$BOOTSTRAP_RESOURCE_GROUP'."
fi

# Reuse the generic ensure_identity/ensure_federated_credential helpers by pointing their
# resource-group/identity-name globals at the bootstrap identity instead of a per-environment one.
RESOURCE_GROUP="$BOOTSTRAP_RESOURCE_GROUP"
IDENTITY_NAME="id-${RESOURCE_PREFIX}-bootstrap"
ENVIRONMENT="bootstrap"
ensure_identity infra-bootstrap

APPLICATION_ID="$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query clientId -o tsv)"
PRINCIPAL_ID="$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query principalId -o tsv)"

# Contributor to create/manage resources, User Access Administrator to grant the per-environment
# identities their own roles (AcrPush/AcrPull/Website Contributor) during provision-azure.sh.
ensure_role_assignment "$PRINCIPAL_ID" Contributor "$subscription_scope"
ensure_role_assignment "$PRINCIPAL_ID" "User Access Administrator" "$subscription_scope"

# workflow_dispatch tokens carry a "ref" subject (not "environment"), scoped to the branch the
# workflow was dispatched from. Both the name-based and numeric-ID subject formats are registered
# defensively, matching the per-environment federated credentials created by provision-azure.sh.
for subject in \
  "repo:${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}:ref:refs/heads/${BOOTSTRAP_BRANCH}" \
  "repo:${GITHUB_OWNER}@${GITHUB_OWNER_ID}/${WORKFLOW_REPOSITORY}@${WORKFLOW_REPOSITORY_ID}:ref:refs/heads/${BOOTSTRAP_BRANCH}"; do
  name="fic-bootstrap"
  [[ "$subject" == repo:*@* ]] && name="fic-bootstrap-numeric-subject"
  ensure_federated_credential "$name" "$subject"
done

echo "Setting repository-level Azure secrets for ${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}..."
printf '%s' "$APPLICATION_ID" |
  gh secret set AZURE_CLIENT_ID --repo "${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}"
printf '%s' "$TENANT_ID" |
  gh secret set AZURE_TENANT_ID --repo "${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}"
printf '%s' "$SUBSCRIPTION_ID" |
  gh secret set AZURE_SUBSCRIPTION_ID --repo "${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}"

echo "Bootstrap complete. infra-setup.yml and infra-teardown.yml can now log in to Azure when dispatched from '$BOOTSTRAP_BRANCH'."
