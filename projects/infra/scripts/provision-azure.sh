#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/environment-common.sh"

[[ $# -eq 1 ]] || { echo "usage: $0 <environment>" >&2; exit 1; }
require_azure_command
require_environment
load_azure_context

az group create --name "$RESOURCE_GROUP" --location "$AZURE_LOCATION" \
  --tags environment="$ENVIRONMENT" purpose=poc-gha-oidc >/dev/null
az acr create --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" \
  --location "$AZURE_LOCATION" --sku "$ACR_SKU" --admin-enabled false >/dev/null

az identity create --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" \
  --location "$AZURE_LOCATION" --tags environment="$ENVIRONMENT" purpose=poc-gha-oidc >/dev/null
APPLICATION_ID="$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query clientId -o tsv)"
PRINCIPAL_ID="$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query principalId -o tsv)"
IDENTITY_ID="$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)"

az appservice plan create --name "$PLAN_NAME" --resource-group "$RESOURCE_GROUP" \
  --location "$AZURE_LOCATION" --is-linux --sku "$APP_SERVICE_SKU" >/dev/null
az webapp create --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" --plan "$PLAN_NAME" \
  --deployment-container-image-name "$PLACEHOLDER_IMAGE" >/dev/null
az webapp identity assign --name "$APP_NAME" --resource-group "$RESOURCE_GROUP" \
  --identities "$IDENTITY_ID" >/dev/null

acr_id="$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv)"
rg_id="$(az group show --name "$RESOURCE_GROUP" --query id -o tsv)"
az role assignment create --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal --role AcrPush --scope "$acr_id" >/dev/null
az role assignment create --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal --role AcrPull --scope "$acr_id" >/dev/null
az role assignment create --assignee-object-id "$PRINCIPAL_ID" --assignee-principal-type ServicePrincipal --role "Website Contributor" --scope "$rg_id" >/dev/null

for subject in \
  "repo:${GITHUB_OWNER}/${PLATFORM_REPOSITORY}:environment:${ENVIRONMENT}" \
  "repo:${GITHUB_OWNER}@${GITHUB_OWNER_ID}/${PLATFORM_REPOSITORY}@${PLATFORM_REPOSITORY_ID}:environment:${ENVIRONMENT}"; do
  name="$FIC_NAME"
  [[ "$subject" == repo:*@* ]] && name="$NUMERIC_FIC_NAME"
  az identity federated-credential create --name "$name" --identity-name "$IDENTITY_NAME" \
    --resource-group "$RESOURCE_GROUP" --issuer https://token.actions.githubusercontent.com \
    --subject "$subject" --audiences api://AzureADTokenExchange >/dev/null
done

write_context
echo "Provisioned Azure resources for $ENVIRONMENT: $RESOURCE_GROUP, $ACR_LOGIN_SERVER, $APP_NAME"
