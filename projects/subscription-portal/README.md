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

## Local Docker build

```powershell
docker build -t subscription-portal:local .
docker run -p 8080:8080 subscription-portal:local
```
