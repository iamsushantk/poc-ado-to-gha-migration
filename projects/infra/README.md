# Infrastructure

## One-time bootstrap

`infra-setup.yml` and `infra-teardown.yml` log in to Azure via OIDC using repository-level secrets
(`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) *before* any per-environment
identity exists. Run this once, locally, signed in with an Azure account that can create role
assignments (e.g. Owner) at the subscription scope:

```bash
./scripts/bootstrap-azure.sh
```

This creates a standing "bootstrap" managed identity, grants it `Contributor` and `User Access
Administrator` at the subscription scope, trusts it for `infra-setup.yml`/`infra-teardown.yml` when
dispatched from `main` (set `BOOTSTRAP_BRANCH` to trust a different branch), and stores its
credentials as repository-level secrets via `gh secret set`. It is idempotent and safe to rerun.
Without this step, the first run of `infra-setup.yml` fails at the "Log in to Azure" step because
those secrets don't exist yet.

## Provisioning environments

Provisioning is split into independent Azure and GitHub steps using only the Azure CLI and GitHub CLI:

```bash
./scripts/provision-azure.sh dev
./scripts/provision-github.sh dev
```

Run Azure first. `provision-azure.sh` checks whether each resource (resource group, Container
Registry, managed identity, App Service plan, web app, role assignments, federated credentials)
already exists before creating it, so rerunning it against an already-provisioned environment
skips existing resources instead of recreating them. The Container Registry name is randomized
only on first creation; subsequent runs reuse whichever registry is already in the resource group.
It also configures the web app's container settings and managed-identity credentials so the App
Service can authenticate to and pull images from that registry (`configure_acr_pull`) — without
this, having the `AcrPull` role alone is not enough for the App Service runtime to pull the image.
The script writes a local, ignored `.provisioning-context` file containing the resource names and
OIDC values required by the GitHub step. Set `PROVISIONING_CONTEXT_FILE` to store that handoff
elsewhere. Azure and GitHub teardown are also independent:

```bash
./scripts/teardown-github.sh dev
./scripts/teardown-azure.sh dev
```

They require authentication only for the provider they operate on and use environment variables for
the owner, workflow repository, Azure location, resource prefix, and SKU overrides. Review each
script before use; teardown is destructive.

When run locally, the scripts derive the repository from `gh repo view`. In GitHub Actions, the
workflows pass `${{ github.repository_owner }}` and `${{ github.event.repository.name }}` and set
`GH_TOKEN`, so each repository manages only its own environments.

The root `infra-setup.yml` and `infra-teardown.yml` workflows expose these operations
manually for `dev`, `sit`, `uat`, and `prod`. Setup always invokes provisioning for the requested
environment, but each Azure resource is skipped if it already exists; teardown skips an environment
that does not exist. Configure the provisioning Azure OIDC secrets and, when required by repository
permissions, `GH_PAT`.

No Terraform configuration or state is required. The scripts query the current Azure CLI session,
create the Azure resources and OIDC identity, and configure the platform GitHub Environment directly.
