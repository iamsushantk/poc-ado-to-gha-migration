# Infrastructure

Provisioning is split into independent Azure and GitHub steps using only the Azure CLI and GitHub CLI:

```bash
./scripts/provision-azure.sh dev
./scripts/provision-github.sh dev
```

Run Azure first. It writes a local, ignored `.provisioning-context` file containing the resource
names and OIDC values required by the GitHub step. Set `PROVISIONING_CONTEXT_FILE` to store that
handoff elsewhere. Azure and GitHub teardown are also independent:

```bash
./scripts/teardown-github.sh dev
./scripts/teardown-azure.sh dev
```

They require authentication only for the provider they operate on and use environment variables for
the owner, platform repository, Azure location, resource prefix, and SKU overrides. Review each
script before use; teardown is destructive.

When run locally, the scripts derive the repository from `gh repo view`. In GitHub Actions, the
workflows pass `${{ github.repository_owner }}` and `${{ github.event.repository.name }}` and set
`GH_TOKEN`, so each repository manages only its own environments.

The root `setup-environment.yml` and `teardown-environment.yml` workflows expose these operations
manually for `dev`, `sit`, `uat`, and `prod`. Setup skips an environment that already exists;
teardown skips an environment that does not exist. Configure the provisioning Azure OIDC secrets
and, when required by repository permissions, `GH_PAT`.

No Terraform configuration or state is required. The scripts query the current Azure CLI session,
create the Azure resources and OIDC identity, and configure the platform GitHub Environment directly.
