# Platform workflows

The deployment workflow centralizes application deployment. Azure OIDC is configured for this project
so application repositories do not need individual Azure federated credentials.

Environment provisioning and teardown are intentionally performed locally with the shell scripts in
`projects/provisioning-scripts/scripts`; there are no Terraform or state-artifact workflows.
