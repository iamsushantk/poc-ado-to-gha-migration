# Subscription portal

This App Router application builds as a standalone container and requests deployment through the
centralized `workflows` project. The request includes the exact commit, target environment,
image name, and source workflow run so the platform can report the deployment back to the caller.

## Prerequisites

Provision the Azure resources, GitHub Environments, and platform OIDC federated credentials before
dispatching a deployment. Configure `WORKFLOW_TOKEN` for the application repository and
the platform workflow repository:

```bash
gh secret set WORKFLOW_TOKEN --repo OWNER/poc-ado-to-gha-migration
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
fail fast, then validates the Docker build (without pushing). ESLint is disabled inside `next build`
(`next.config.js`) since it already runs as a separate, earlier CI step — this keeps lint out of the
(slower) Docker build.

## Local Docker build

```powershell
docker build -t subscription-portal:local .
docker run -p 8080:8080 subscription-portal:local
```

## Build and deployment

On push to `main` (or manual dispatch with a chosen environment), CI additionally builds and pushes
the image to that environment's Azure Container Registry, tagged with the commit SHA, then calls
`subscription-portal-cd.yml` to dispatch the deployment request. `workflows-cd.yml` only configures
the App Service to pull the already-pushed tag — it does not build or push images. See the root
README and `projects/workflows` for the CD flow.
