# Cloud Run Deployment

## Capability
Deploy MCP servers on Google Cloud Run with production-ready infrastructure including auto-scaling, health checks, and observability.

## Terraform Resources
| Resource | Purpose | Key Configuration |
|----------|---------|-------------------|
| `google_cloud_run_v2_service` | Main Cloud Run service | `min_instances`, `max_instances`, `ingress` |
| `google_cloud_run_v2_service_iam_member` | Invoker permissions | `role = "roles/run.invoker"` |

## Usage Examples

### Basic Deployment
```hcl
module "mcp_cloudrun" {
  source     = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/cloud-run"
  name       = "my-mcp-server"
  region     = "us-central1"
  project_id = "my-project"
  image      = "gcr.io/my-project/my-mcp-server:latest"
  
  min_instances = 0
  max_instances = 10
}
```

### Production Deployment
```hcl
module "mcp_cloudrun" {
  source              = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/cloud-run"
  name                = "mcp-prod"
  region              = "us-central1"
  project_id          = "my-project"
  image               = "gcr.io/my-project/mcp@sha256:abc123"  # Pin to digest
  service_account_email = module.iam.service_accounts["mcp-sa"].email
  
  min_instances = 1   # Avoid cold starts
  max_instances = 20
  cpu           = "2000m"
  memory        = "2048Mi"
  timeout_seconds = 120
  
  ingress               = "internal"
  allow_unauthenticated = false
}
```

## Error Handling
- **Cold start timeout**: Increase startup probe threshold or set `min_instances = 1`
- **OOM kills**: Increase memory limit
- **High latency**: Increase CPU allocation or `max_instances`

## Security Considerations
- Use `ingress = "internal"` for private services
- Set `allow_unauthenticated = false` and use IAM for access control
- Always use Secret Manager for credentials, never plain env vars
- Pin container images to digest in production
