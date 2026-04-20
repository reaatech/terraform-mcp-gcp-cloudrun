# IAM Configuration

## Capability
Create service accounts with least-privilege IAM bindings for project-level and Cloud Run service-level permissions.

## Terraform Resources
| Resource | Purpose | Key Configuration |
|----------|---------|-------------------|
| `google_service_account` | Service account creation | `display_name`, `description` |
| `google_project_iam_member` | Project-level bindings | Least privilege roles |
| `google_cloud_run_v2_service_iam_member` | Cloud Run v2 bindings | `roles/run.invoker` |

## Usage Examples

### Basic Service Account
```hcl
module "iam" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/iam"

  project_id = "my-project"

  service_accounts = {
    mcp-sa = {
      account_id   = "mcp-service-sa"
      display_name = "MCP Server Service Account"
      description  = "Service account for MCP Cloud Run deployment"
    }
  }
  bindings = []
}
```

### Service Account with IAM Bindings
```hcl
module "iam" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/iam"

  project_id = "my-project"

  service_accounts = {
    mcp-sa = {
      account_id   = "mcp-service-sa"
      display_name = "MCP Server Service Account"
    }
  }

  bindings = [
    {
      member = "serviceAccount:mcp-sa@my-project.iam.gserviceaccount.com"
      role   = "roles/datastore.user"
    },
    {
      member = "serviceAccount:mcp-sa@my-project.iam.gserviceaccount.com"
      role   = "roles/cloudtrace.agent"
    },
  ]
}
```

## Error Handling
- **Service account creation fails**: Ensure IAM API is enabled
- **Binding creation fails**: Verify role exists and member is valid
- **Circular dependency**: Create service accounts before referencing in other modules

## Security Considerations
- Use one service account per MCP server for isolation
- Grant only required roles (least privilege principle)
- Never create user-managed service account keys
- Use Workload Identity for GKE deployments
- Regularly audit IAM bindings quarterly
- Avoid `roles/owner` or `roles/editor` - use specific roles

## Outputs
| Output | Description |
|--------|-------------|
| `service_account_emails` | Map of service account names to emails |
| `service_accounts` | Map of service account details (email, unique_id) |