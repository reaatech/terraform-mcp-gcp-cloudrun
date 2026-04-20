# Basic Example

A minimal single-service deployment of an MCP server on Cloud Run with Firestore for session state.

## Use Case

Quick testing and development of MCP servers with minimal infrastructure.

## Resources Created

- Cloud Run service (scale-to-zero enabled)
- Firestore database (single region)
- Service account with least privilege IAM
- Monitoring dashboard and alerts

## Prerequisites

- Terraform >= 1.6
- GCP project with billing enabled
- Container image in GCR or Artifact Registry

## Usage

```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply configuration
terraform apply

# Get the service URL
terraform output mcp_server_url

# Test the health endpoint
curl $(terraform output -raw mcp_server_url)/health
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP project ID | - |
| `region` | GCP region | `us-central1` |
| `mcp_server_name` | Name of the MCP server | `my-mcp-server` |
| `mcp_server_image` | Container image URL | `gcr.io/google-samples/hello-app:1.0` |
| `firestore_database_id` | Firestore database ID | `(default)` |
| `firestore_location` | Firestore location | `us-central` |
| `alert_email` | Email for monitoring alerts | `null` |

## Outputs

| Output | Description |
|--------|-------------|
| `mcp_server_url` | The Cloud Run service URL |
| `mcp_server_name` | The Cloud Run service name |
| `service_account_email` | Service account email |
| `firestore_database` | Firestore database name |
| `monitoring_dashboard_url` | Cloud Monitoring dashboard URL |