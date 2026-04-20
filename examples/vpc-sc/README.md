# VPC Service Controls Example

MCP server deployment compatible with VPC Service Controls. Features internal-only ingress, VPC connector, and strict IAM.

## Use Case

Production deployments requiring network isolation and VPC Service Controls compatibility.

## Security Features

- **Internal ingress** — Service not exposed to public internet
- **VPC connector** — Private network connectivity
- **No unauthenticated access** — All invocations require IAM authorization
- **Delete protection** — Firestore database protected against accidental deletion
- **Point-in-time recovery** — Firestore with PITR enabled

## Prerequisites

- Terraform >= 1.6
- GCP project with VPC Service Controls perimeter (recommended)
- VPC Access connector created
- Container image in GCR or Artifact Registry

## Usage

```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply configuration
terraform apply

# Get the service URL (only accessible within VPC)
terraform output mcp_server_url
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP project ID | - |
| `region` | GCP region | `us-central1` |
| `mcp_server_name` | Name of the MCP server | `my-mcp-server` |
| `mcp_server_image` | Container image URL | `gcr.io/google-samples/hello-app:1.0` |
| `vpc_connector` | VPC Access connector name | `null` |
| `firestore_database_id` | Firestore database ID | `(default)` |
| `firestore_location` | Firestore location | `us-central` |
| `delete_protection` | Enable Firestore delete protection | `true` |
| `alert_email` | Email for monitoring alerts | `null` |
| `invoker_members` | IAM members allowed to invoke | `[]` |

## Outputs

| Output | Description |
|--------|-------------|
| `mcp_server_url` | Internal Cloud Run service URL |
| `mcp_server_name` | Cloud Run service name |
| `service_account_email` | Service account email |
| `firestore_database` | Firestore database name |
| `monitoring_dashboard_url` | Cloud Monitoring dashboard URL |