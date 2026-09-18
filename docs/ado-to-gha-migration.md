# Azure DevOps to GitHub Actions migration

| Azure DevOps concept | GitHub Actions target |
| --- | --- |
| YAML pipeline | Workflow in `.github/workflows` |
| Variable group / secret variable | Repository or Environment variable/secret |
| Service connection | OIDC login with `azure/login` and environment-scoped secrets |
| Stage approval | Protected GitHub Environment reviewers |
| Pipeline artifact | Actions artifact with explicit retention |
| Pipeline resource trigger | `workflow_run`, `repository_dispatch`, or reusable workflow |
| Build number | Full commit SHA and `GITHUB_RUN_ID` |

## Contracts

- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` are repository secrets used
  for the provisioning identity.
- The platform deployment job receives `application_repository`, `ref`, `environment`, and
  `image_name` in a `repository_dispatch` payload.
- Azure federated credentials trust the platform workflow and its protected GitHub Environment.
- Application repositories only need a platform workflow token and non-secret environment selection;
  Azure credentials remain centralized.

## Migration sequence

1. Create GitHub Environments and assign required reviewers/branch protections.
2. Configure the provisioning identity and least-privilege repository secrets.
3. Run the shell provisioning script for one non-production environment and verify the OIDC login.
4. Run an application deployment from an immutable commit and verify the callback/summary.
5. Migrate approval rules and production environments only after the lower environments pass.
6. Keep the Azure DevOps pipeline disabled but available during the rollback window.

Never commit access tokens or generated credentials. Provisioning is intentionally script-based for
this POC; if infrastructure grows, add a reviewed remote state solution as a separate design rather
than reintroducing local Terraform state artifacts.
