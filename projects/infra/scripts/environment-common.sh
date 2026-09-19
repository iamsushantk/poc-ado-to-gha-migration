#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

ENVIRONMENT="${1:-}"
RESOURCE_PREFIX="${RESOURCE_PREFIX:-subscription-portal}"
AZURE_LOCATION="${AZURE_LOCATION:-australiaeast}"
ACR_SKU="${ACR_SKU:-Basic}"
APP_SERVICE_SKU="${APP_SERVICE_SKU:-B1}"
GITHUB_OWNER="${GITHUB_OWNER:-}"
WORKFLOW_REPOSITORY="${WORKFLOW_REPOSITORY:-}"
GITHUB_OWNER_ID="${GITHUB_OWNER_ID:-}"
WORKFLOW_REPOSITORY_ID="${WORKFLOW_REPOSITORY_ID:-}"
PLACEHOLDER_IMAGE="${PLACEHOLDER_IMAGE:-mcr.microsoft.com/appsvc/staticsite:latest}"
# The subscription-portal image is not yet built when the App Service is created, so it starts
# with a public placeholder image; the first CD run replaces it with the real container image.

require_azure_command() {
  command -v az >/dev/null || { echo "error: Azure CLI (az) is required" >&2; exit 1; }
}

require_github_command() {
  command -v gh >/dev/null || { echo "error: GitHub CLI (gh) is required" >&2; exit 1; }
}

load_github_context() {
  if [[ -z "$GITHUB_OWNER" || -z "$WORKFLOW_REPOSITORY" ]]; then
    local repository
    repository="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
    GITHUB_OWNER="${repository%%/*}"
    WORKFLOW_REPOSITORY="${repository#*/}"
  fi
  [[ -n "$GITHUB_OWNER" && -n "$WORKFLOW_REPOSITORY" ]] ||
    { echo "error: GitHub owner and repository could not be determined" >&2; exit 1; }
  # The numeric owner/repo IDs are only needed for the ID-based OIDC subject variant and are
  # repo-specific, so they are always resolved from the GitHub API rather than hardcoded, unless
  # explicitly overridden via environment variables.
  if [[ -z "$GITHUB_OWNER_ID" ]]; then
    GITHUB_OWNER_ID="$(gh api "users/${GITHUB_OWNER}" --jq '.id' 2>/dev/null || gh api "orgs/${GITHUB_OWNER}" --jq '.id')"
  fi
  if [[ -z "$WORKFLOW_REPOSITORY_ID" ]]; then
    WORKFLOW_REPOSITORY_ID="$(gh api "repos/${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}" --jq '.id')"
  fi
  [[ -n "$GITHUB_OWNER_ID" && -n "$WORKFLOW_REPOSITORY_ID" ]] ||
    { echo "error: GitHub owner/repository numeric IDs could not be determined" >&2; exit 1; }
}

require_environment() {
  [[ "$ENVIRONMENT" =~ ^[a-z][a-z0-9-]*$ ]] ||
    { echo "error: use a lowercase environment name such as uat" >&2; exit 1; }
}

load_resource_context() {
  RESOURCE_GROUP="rg-${RESOURCE_PREFIX}-${ENVIRONMENT}"
  PLAN_NAME="plan-${RESOURCE_PREFIX}-${ENVIRONMENT}"
  APP_NAME="app-${RESOURCE_PREFIX}-${ENVIRONMENT}"
  IDENTITY_NAME="id-${RESOURCE_PREFIX}-${ENVIRONMENT}"
  FIC_NAME="fic-${RESOURCE_PREFIX}-${ENVIRONMENT}"
  NUMERIC_FIC_NAME="${FIC_NAME}-numeric-subject"
}

# Each ensure_* helper checks whether the resource already exists before creating it, so
# rerunning provision-azure.sh against an already-provisioned environment is safe and fast.

ensure_resource_group() {
  if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "Resource group '$RESOURCE_GROUP' already exists; skipping creation."
  else
    az group create --name "$RESOURCE_GROUP" --location "$AZURE_LOCATION" \
      --tags environment="$ENVIRONMENT" purpose=subscription-portal >/dev/null
    echo "Created resource group '$RESOURCE_GROUP'."
  fi
}

# The ACR name must be globally unique, so it is randomized on first creation. Reuse the ACR
# already present in the resource group instead of generating (and losing track of) a new name.
resolve_acr_name() {
  local existing
  existing="$(az acr list --resource-group "$RESOURCE_GROUP" --query '[0].name' -o tsv 2>/dev/null || true)"
  if [[ -n "$existing" ]]; then
    ACR_NAME="$existing"
    echo "Found existing Azure Container Registry '$ACR_NAME'; skipping creation."
  else
    ACR_NAME="acr$(tr -d '-' <<< "$RESOURCE_PREFIX")${ENVIRONMENT}$(printf '%04d' "$(( $(od -An -N2 -tu2 /dev/urandom) % 10000 ))")"
    az acr create --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" \
      --location "$AZURE_LOCATION" --sku "$ACR_SKU" --admin-enabled false >/dev/null
    echo "Created Azure Container Registry '$ACR_NAME'."
  fi
  ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"
}

ensure_identity() {
  local purpose="${1:-subscription-portal}"
  if az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "Managed identity '$IDENTITY_NAME' already exists; skipping creation."
  else
    az identity create --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" \
      --location "$AZURE_LOCATION" --tags environment="$ENVIRONMENT" purpose="$purpose" >/dev/null
    echo "Created managed identity '$IDENTITY_NAME'."
  fi
}

ensure_app_service_plan() {
  if az appservice plan show --name "$PLAN_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "App Service plan '$PLAN_NAME' already exists; skipping creation."
  else
    az appservice plan create --name "$PLAN_NAME" --resource-group "$RESOURCE_GROUP" \
      --location "$AZURE_LOCATION" --is-linux --sku "$APP_SERVICE_SKU" >/dev/null
    echo "Created App Service plan '$PLAN_NAME'."
  fi
}

ensure_web_app() {
  if az webapp show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "Web app '$APP_NAME' already exists; skipping creation."
  else
    az webapp create --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --plan "$PLAN_NAME" \
      --deployment-container-image-name "$PLACEHOLDER_IMAGE" >/dev/null
    echo "Created web app '$APP_NAME'."
  fi
}

ensure_web_app_identity() {
  local identity_id="$1"
  if az webapp identity show --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" \
      --query "userAssignedIdentities.\"${identity_id}\"" -o tsv 2>/dev/null | grep -q .; then
    echo "Managed identity already assigned to '$APP_NAME'; skipping."
  else
    az webapp identity assign --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" \
      --identities "$identity_id" >/dev/null
    echo "Assigned managed identity to '$APP_NAME'."
  fi
}

# Without this, the web app has no way to authenticate to ACR and pulls fail even though the
# identity has AcrPull/AcrPush roles — those roles only apply once the app is actually configured
# to authenticate with that identity when pulling.
configure_acr_pull() {
  local application_id="$1"
  az webapp config container set --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" \
    --container-registry-url "https://$ACR_LOGIN_SERVER" >/dev/null
  az resource update --resource-group "$RESOURCE_GROUP" --name "$APP_NAME" \
    --resource-type "Microsoft.Web/sites" \
    --set properties.siteConfig.acrUseManagedIdentityCreds=true \
    --set properties.siteConfig.acrUserManagedIdentityID="$application_id" >/dev/null
  echo "Configured '$APP_NAME' to pull from '$ACR_LOGIN_SERVER' using its managed identity."
}

ensure_role_assignment() {
  local principal_id="$1" role="$2" scope="$3"
  if az role assignment list --assignee-object-id "$principal_id" --role "$role" --scope "$scope" \
      --query '[0].id' -o tsv 2>/dev/null | grep -q .; then
    echo "Role '$role' already assigned at scope '$scope'; skipping."
    return
  fi

  # A freshly created identity's principal can take a few seconds to replicate through Azure AD;
  # role assignment creation can fail transiently (e.g. PrincipalNotFound/MissingSubscription)
  # until it does, so retry briefly instead of failing the whole script.
  local attempt
  for attempt in 1 2 3 4 5; do
    if az role assignment create --assignee-object-id "$principal_id" --assignee-principal-type ServicePrincipal \
        --role "$role" --scope "$scope" >/dev/null 2>&1; then
      echo "Assigned role '$role' at scope '$scope'."
      return
    fi
    echo "Role assignment for '$role' at scope '$scope' not ready yet (attempt $attempt/5); retrying in 10s..."
    sleep 10
  done
  echo "error: failed to assign role '$role' at scope '$scope' after retries" >&2
  exit 1
}

ensure_federated_credential() {
  local name="$1" subject="$2"
  if az identity federated-credential show --name "$name" --identity-name "$IDENTITY_NAME" \
      --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "Federated credential '$name' already exists; skipping."
  else
    az identity federated-credential create --name "$name" --identity-name "$IDENTITY_NAME" \
      --resource-group "$RESOURCE_GROUP" --issuer https://token.actions.githubusercontent.com \
      --subject "$subject" --audiences api://AzureADTokenExchange >/dev/null
    echo "Created federated credential '$name'."
  fi
}

load_azure_context() {
  load_resource_context
  load_github_context
  SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
  TENANT_ID="$(az account show --query tenantId -o tsv)"
  # APPLICATION_ID is resolved later, once the managed identity is known to exist
  # (ensure_identity may need to create it first on a fresh environment).
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
WORKFLOW_REPOSITORY=$WORKFLOW_REPOSITORY
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
  gh api --method PUT "repos/${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}/environments/${ENVIRONMENT}" >/dev/null
  printf '%s' "$APPLICATION_ID" |
    gh secret set AZURE_CLIENT_ID --repo "${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}" --env "$ENVIRONMENT"
  printf '%s' "$TENANT_ID" |
    gh secret set AZURE_TENANT_ID --repo "${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}" --env "$ENVIRONMENT"
  printf '%s' "$SUBSCRIPTION_ID" |
    gh secret set AZURE_SUBSCRIPTION_ID --repo "${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}" --env "$ENVIRONMENT"
  gh variable set ACR_LOGIN_SERVER --repo "${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}" --env "$ENVIRONMENT" --body "$ACR_LOGIN_SERVER"
  gh variable set RESOURCE_GROUP --repo "${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}" --env "$ENVIRONMENT" --body "$RESOURCE_GROUP"
  gh variable set APP_SERVICE_NAME --repo "${GITHUB_OWNER}/${WORKFLOW_REPOSITORY}" --env "$ENVIRONMENT" --body "$APP_NAME"
}