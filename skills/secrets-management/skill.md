# Secrets Management

## Capability
Create and manage secrets in Google Secret Manager with automatic replication and least-privilege accessor IAM.

## Terraform Resources
| Resource | Purpose | Key Configuration |
|----------|---------|-------------------|
| `google_secret_manager_secret` | Secret definitions | `replication.auto` |
| `google_secret_manager_secret_iam_member` | Accessor bindings | `roles/secretmanager.secretAccessor` |

## Usage Examples

### Basic Secret
```hcl
module "secrets" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/secrets"

  project_id = "my-project"
  secrets = {
    api-key = {
      secret_id = "mcp-api-key"
    }
  }
  accessors = ["sa@my-project.iam.gserviceaccount.com"]
}
```

### Production Secrets with Labels
```hcl
module "secrets" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/secrets"

  project_id = "my-project"
  secrets = {
    api-key = {
      secret_id = "mcp-api-key"
      labels    = { environment = "prod", app = "mcp" }
    }
    db-password = {
      secret_id = "mcp-db-password"
      labels    = { environment = "prod", app = "mcp" }
    }
  }
  accessors = [
    "sa@my-project.iam.gserviceaccount.com",
  ]
}
```

## Error Handling
- **Secret creation fails**: Ensure Secret Manager API is enabled
- **Accessor binding fails**: Verify service account exists before adding accessors
- **Replication issue**: Use `replication { auto {} }` for multi-region replication

## Security Considerations
- Never store secret values in Terraform state or code
- Create secrets manually after `terraform apply`:
  ```bash
  echo -n "your-secret-value" | gcloud secrets versions add SECRET_ID --data-file=-
  ```
- Grant only `secretAccessor` role, not admin
- Rotate secrets regularly using `gcloud secrets versions add`
- Use workload identity instead of service account keys

## Outputs
| Output | Description |
|--------|-------------|
| `secret_names` | Map of secret names to secret IDs |