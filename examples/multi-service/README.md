# Multi-Service Example

Multiple MCP servers with Pub/Sub for async task distribution. Features an orchestrator that dispatches tasks to agents via message queues.

## Use Case

Orchestrator + agent architectures where a central orchestrator coordinates work across multiple specialized agents using Pub/Sub message queues.

## Architecture

```
┌──────────────┐     ┌───────────────┐     ┌─────────────┐
│   Client     │────▶│ Orchestrator  │────▶│  Pub/Sub    │
└──────────────┘     └───────────────┘     └─────────────┘
                            │                     │
                            ▼                     ▼
                      ┌─────────────┐     ┌─────────────┐
                      │  Firestore  │     │   Agents    │
                      └─────────────┘     └─────────────┘
```

## Resources Created

- Orchestrator Cloud Run service (scale-to-zero)
- Agent Cloud Run services (scale-to-zero, auto-scaling to 5)
- Pub/Sub topics: `orchestrator-tasks`, `agent-results`, `mcp-dlq`
- Pub/Sub subscriptions with dead-letter queue
- Firestore database
- Service accounts with least privilege IAM

## Prerequisites

- Terraform >= 1.6
- GCP project with billing enabled
- Container images in GCR or Artifact Registry

## Usage

```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply configuration
terraform apply

# Get service URLs
terraform output orchestrator_url
terraform output service_urls
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP project ID | - |
| `region` | GCP region | `us-central1` |
| `orchestrator_image` | Orchestrator container image | `gcr.io/google-samples/hello-app:1.0` |
| `agents` | List of agent configurations | `[{name = "agent-a", image = "gcr.io/google-samples/hello-app:2.0"}]` |
| `firestore_database_id` | Firestore database ID | `(default)` |
| `firestore_location` | Firestore location | `us-central` |
| `alert_email` | Email for monitoring alerts | `null` |

## Outputs

| Output | Description |
|--------|-------------|
| `orchestrator_url` | Orchestrator Cloud Run service URL |
| `service_urls` | Map of all service URLs |
| `service_accounts` | Map of service account emails |
| `firestore_database` | Firestore database name |
| `pubsub_topics` | Pub/Sub topic names |
| `pubsub_subscriptions` | Pub/Sub subscription names |
| `monitoring_dashboard_urls` | Map of service name to Cloud Monitoring dashboard URL |