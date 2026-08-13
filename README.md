# aws-enterprise-infrastructure-package

This package contains a self-contained snapshot of the Terraform infrastructure and Kubernetes manifests described for the enterprise EKS project.

Included paths:
- `.github/workflows/terraform-ci-cd.yml`
- `terraform/` (Terraform configs, `terraform.tfvars.example`)
- `terraform/k8s-manifests/` (Kubernetes manifests)

Packaging instructions (Windows PowerShell):

```powershell
# From the directory that contains the aws-enterprise-infrastructure-package folder
Compress-Archive -Path .\aws-enterprise-infrastructure-package\* -DestinationPath aws-enterprise-infrastructure.zip -Force
```

Packaging instructions (Linux / macOS / WSL):

```bash
# From the directory that contains the aws-enterprise-infrastructure-package folder
zip -r aws-enterprise-infrastructure.zip aws-enterprise-infrastructure-package
```

Usage notes:
- Update `terraform/backend.tf` backend `bucket` and `dynamodb_table` values or pass `-backend-config` during `terraform init`.
- Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and update secrets (do not commit secrets to source control).
- The GitHub Actions workflow expects AWS credentials in `secrets.AWS_ACCESS_KEY_ID` and `secrets.AWS_SECRET_ACCESS_KEY`, and `vars.AWS_REGION` defined in repository variables.
