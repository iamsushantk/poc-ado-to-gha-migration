# Subscription portal

This App Router application builds as a standalone container and requests deployment through the
centralized `workflows` project. The request includes the exact commit, target environment,
image name, and source workflow run so the platform can report the deployment back to the caller.

## Prerequisites

Provision the Azure resources, GitHub Environments, and platform OIDC federated credentials before
dispatching a deployment. Configure `PLATFORM_WORKFLOW_TOKEN` for the application repository and
the platform workflow repository:

```bash
gh secret set PLATFORM_WORKFLOW_TOKEN --repo OWNER/poc-ado-to-gha-migration
```

## Local development

```powershell
npm install
npm run dev --workspace projects/subscription-portal
```

## Validation

```powershell
npm run lint --workspace projects/subscription-portal
npm run format:check --workspace projects/subscription-portal
```

CI (`subscription-portal-ci.yml`) runs lint and `format:check` first so formatting/lint mistakes
fail fast, then builds the Docker image (without pushing) to validate the same multi-stage build
used for deployment. ESLint is disabled inside `next build` (`next.config.js`) since it already
runs as a separate, earlier CI step — this keeps lint out of the (slower) Docker build.

## Local Docker build

```powershell
docker build -t subscription-portal:local .
docker run -p 8080:8080 subscription-portal:local
```

## Deployment

The image is built and pushed to Azure Container Registry with the commit SHA as its tag, then the
App Service is updated to pull that tag. See the root README and `projects/workflows` for the CD
flow.
