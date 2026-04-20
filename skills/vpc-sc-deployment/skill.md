# VPC Service Controls Deployment

## Capability
Deploy MCP servers with VPC Service Controls compatibility including internal-only ingress, VPC connector, and Private Service Connect.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    VPC Service Controls                      │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │   Client    │───▶│ Cloud Run   │───▶│  Firestore  │    │
│  │  (on-prem) │    │ (internal)  │    │ (in VPC)    │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  VPC Connector  │
                    │  (Serverless)  │
                    └─────────────────┘
```

## Terraform Resources
| Resource | Purpose | Key Configuration |
|----------|---------|-------------------|
| `google_cloud_run_v2_service` | Internal Cloud Run | `ingress = "internal"` |
| `google_vpc_access` | Serverless VPC access | `vpc_connector` |

## Usage Examples

### Internal-Only Service
```hcl
module "mcp_vpc" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/cloud-run"

  name                = "mcp-internal"
  region              = "us-central1"
  project_id          = "my-project"
  image               = "gcr.io/my-project/mcp:latest"
  service_account_email = module.iam.service_account_emails["mcp-sa"]

  vpc_connector = "my-vpc-connector"

  ingress               = "internal"
  allow_unauthenticated = false

  env_vars = {
    VPC_SERVICE_CONTROLS    = "enabled"
    PRIVATE_SERVICE_CONNECT = "true"
  }
}
```

### Service with IAM Invoker
```hcl
module "mcp_vpc" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/cloud-run"

  name                = "mcp-internal"
  region              = "us-central1"
  project_id          = "my-project"
  image               = "gcr.io/my-project/mcp:latest"
  service_account_email = module.iam.service_account_emails["mcp-sa"]

  vpc_connector = "my-vpc-connector"

  ingress               = "internal"
  allow_unauthenticated = false

  invoker_members = [
    "serviceAccount:other-sa@my-project.iam.gserviceaccount.com",
    "group:team@example.com",
  ]
}
```

## Error Handling
- **VPC connector not found**: Create VPC connector before deploying
- **Internal service unreachable**: Verify VPC firewall rules allow traffic
- **Ingress validation error**: Ensure `ingress = "internal"` for VPC-SC

## Security Considerations
- Always use `ingress = "internal"` for VPC-SC compatibility
- Set `allow_unauthenticated = false` and control access via IAM
- Use VPC connector for private network access
- Enable Private Service Connect for Google APIs access
- Configure Cloud Armor for additional DDoS protection
- Use Cloud Run's built-in encryption at rest and in transit

## Prerequisites
1. Create a VPC Access connector:
   ```bash
   gcloud compute networks vpc-access connectors create my-connector \
     --region=us-central1 \
     --network=default \
     --range=10.8.0.0/28
   ```

2. Configure VPC Service Controls perimeter (optional)
3. Set up Private Service Connect for Google APIs