# poc-ado-to-gha-migration

Migration-ready monorepo for moving an Azure DevOps delivery model to GitHub Actions. It contains the
application, the centralized platform workflow, and simple CLI provisioning scripts for the Azure and
GitHub integration.

## Projects

- `projects/infra` - Azure CLI/GitHub CLI environment lifecycle scripts.
- `projects/subscription-portal` - Next.js App Router application and its workflow that dispatches an exact
  commit/environment deployment request.
- `projects/workflows` - centralized deployment and platform workflows.

## Prerequisites

Node.js 20+, npm, Bash, Azure CLI, GitHub CLI, and Docker are required for the full workflow.
Authenticate `az` and `gh` locally before running provisioning scripts.
Repository identity is derived from the current GitHub repository context in Actions and from
`gh repo view` locally; set `GITHUB_OWNER` and `WORKFLOW_REPOSITORY` only when intentionally
targeting a different repository.

## Local development

```powershell
npm install
npm run dev --workspace projects/subscription-portal
```

Run the Next.js checks with `npm run lint` and `npm run build`, or trigger the repository's
Next.js-specific workflow manually. The shell validation requires Bash (Git Bash or WSL on Windows).

## Deployment model

The app workflow dispatches a deployment request to the centralized platform workflow. The platform
workflow checks out the requested application commit, builds and pushes its image to Azure Container
Registry, and updates the target App Service using Azure OIDC. Azure trusts the platform workflow,
not each application repository.

Provision environments in two explicit steps:
`projects/infra/scripts/provision-azure.sh <environment>` followed by
`projects/infra/scripts/provision-github.sh <environment>`. Teardown is similarly
split into GitHub first and Azure second, with confirmation required for each destructive action.
Terraform and Terraform state handoff are deliberately not part of this simplified POC.

The same operations are available through the manually triggered root workflows
`.github/workflows/infra-setup.yml` and `.github/workflows/infra-teardown.yml` for `dev`, `sit`,
`uat`, and `prod`. Setup always invokes provisioning for the requested environment, but Azure
provisioning checks each resource first and skips creation when it already exists (reusing the
existing Container Registry rather than generating a new random name); teardown skips an
environment that is not present. Before running either workflow for the first time, run
`projects/infra/scripts/bootstrap-azure.sh` once locally — it creates a standing identity and
repository-level secrets that let these two workflows log in to Azure before any per-environment
identity exists. See `projects/infra/README.md` for details.

See `docs/ado-to-gha-migration.md` for the Azure DevOps mapping, secrets and permissions contract,
environment approvals, state handoff, and rollback guidance.
