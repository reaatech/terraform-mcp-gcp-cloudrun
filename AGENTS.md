---
agent_id: "terraform-mcp-gcp-cloudrun"
display_name: "Terraform MCP GCP Cloud Run"
version: "1.0.0"
description: "MCP server for deploying agents on GCP Cloud Run using Terraform"
type: "mcp"
confidence_threshold: 0.9
---

# terraform-mcp-gcp-cloudrun — Agent Deployment Guide

## What this is

This document defines how to use `terraform-mcp-gcp-cloudrun` to deploy MCP servers on
Google Cloud Run with production-ready infrastructure. It covers module usage,
configuration patterns, security considerations, and integration with multi-agent
systems.

**Target audience:** Platform engineers and DevOps teams deploying MCP servers to GCP
who need a battle-tested infrastructure template with observability, security, and
scalability built in.

---

## Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   MCP Client    │────▶│   Cloud Run      │────▶│   Firestore    │
│                 │     │   Service        │     │  (Sessions)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │  Secret Manager  │
                       │  (API Keys)      │
                       └──────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │     Pub/Sub      │
                       │  (Async Tasks)   │
                       └──────────────────┘
```

### Key Components

| Component | Module | Purpose |
|-----------|--------|---------|
| **Cloud Run Service** | `modules/cloud-run/` | Stateless compute with auto-scaling |
| **Firestore Database** | `modules/firestore/` | Session state persistence |
| **Secret Manager** | `modules/secrets/` | API keys and credentials |
| **Pub/Sub** | `modules/pubsub/` | Async task distribution |
| **IAM** | `modules/iam/` | Service accounts and permissions |
| **Monitoring** | `modules/monitoring/` | Observability and alerting |

---

## Quick Start

### Prerequisites

- Terraform >= 1.6
- `gcloud` CLI authenticated (`gcloud auth application-default login`)
- A GCP project with billing enabled
- A GCS bucket for remote state (create once)

### 5-Minute Deployment

```bash
# 1. Clone the module
git clone https://github.com/reaatech/terraform-mcp-gcp-cloudrun.git
cd terraform-mcp-gcp-cloudrun/environments/dev

# 2. Configure backend
cat > backend.tf <<EOF
terraform {
  backend "gcs" {
    bucket = "your-tfstate-bucket"
    prefix = "terraform/dev"
  }
}
EOF

# 3. Configure variables
cat > terraform.tfvars <<EOF
project_id = "your-gcp-project"
region     = "us-central1"

mcp_servers = [
  {
    name  = "my-mcp-server"
    image = "gcr.io/your-gcp-project/my-mcp-server:latest"
  }
]
EOF

# 4. Deploy
terraform init
terraform plan
terraform apply
```

### Verify Deployment

```bash
# Get the Cloud Run service URL
export SERVICE_URL=$(terraform output -raw cloud_run_services | jq -r '.[].url')

# Test the health endpoint
curl $SERVICE_URL/health

# Check in GCP Console
# - Cloud Run service is running
# - Firestore database exists
# - Secret Manager secrets created
# - Pub/Sub topics exist
```

---

## Module Usage

### Basic Single-Service Deployment

```hcl
module "mcp_cloudrun" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/cloud-run"

  name                = "my-mcp-server"
  region              = "us-central1"
  project_id          = "my-project"
  image               = "gcr.io/my-project/my-mcp-server:latest"
  service_account_email = module.iam.service_accounts["mcp-sa"].email

  min_instances = 0  # Scale to zero for dev
  max_instances = 5  # Limit for cost control

  cpu              = "1000m"
  memory           = "512Mi"
  timeout_seconds  = 60
  concurrency      = 80

  allow_unauthenticated = true  # For testing only!

  env_vars = {
    LOG_LEVEL = "INFO"
    NODE_ENV  = "production"
  }

  secret_env_vars = {
    API_KEY = {
      secret  = "mcp-api-key"
      version = "latest"
    }
  }

  labels = {
    environment = "prod"
  }
}
```

### Multi-Service with Pub/Sub

```hcl
# Create Pub/Sub topics for async communication
module "pubsub" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/pubsub"

  project_id = "my-project"

  topics = ["mcp-tasks", "mcp-results", "mcp-events"]

  subscriptions = {
    mcp-tasks-sub = {
      topic                   = "mcp-tasks"
      push_endpoint           = module.mcp_cloudrun.service_url
      push_service_account    = module.iam.service_accounts["mcp-sa"].email
      ack_deadline_seconds    = 30
      message_retention_seconds = 604800  # 7 days
    }
  }
}

# Deploy multiple MCP servers
module "orchestrator" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/cloud-run"

  name     = "orchestrator"
  image    = "gcr.io/my-project/orchestrator:latest"
  # ... other config
}

module "agent_a" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/cloud-run"

  name     = "agent-a"
  image    = "gcr.io/my-project/agent-a:latest"
  # ... other config
}
```

### VPC Service Controls Compatible

```hcl
module "mcp_vpc" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/cloud-run"

  name                = "mcp-internal"
  image               = "gcr.io/my-project/mcp-internal:latest"
  service_account_email = module.iam.service_accounts["mcp-sa"].email

  # Private networking
  vpc_connector = "my-vpc-connector"

  # Internal only
  ingress               = "internal"
  allow_unauthenticated = false

  # Restricted environment
  env_vars = {
    VPC_SERVICE_CONTROLS    = "enabled"
    PRIVATE_SERVICE_CONNECT = "true"
  }
}
```

---

## Configuration Reference

### Cloud Run Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `name` | string | — | Service name (required) |
| `region` | string | — | GCP region (required) |
| `project_id` | string | — | GCP project ID (required) |
| `image` | string | — | Container image URI (required) |
| `service_account_email` | string | — | Service account email (required) |
| `min_instances` | number | 0 | Minimum instances (0 = scale to zero) |
| `max_instances` | number | 10 | Maximum instances |
| `cpu` | string | "1000m" | CPU limit |
| `memory` | string | "512Mi" | Memory limit |
| `timeout_seconds` | number | 60 | Request timeout |
| `concurrency` | number | 80 | Max concurrent requests per instance |
| `ingress` | string | "internal-and-cloud-load-balancing" | Ingress setting |
| `allow_unauthenticated` | bool | false | Allow unauthenticated invocations |
| `env_vars` | map(string) | {} | Plain environment variables |
| `secret_env_vars` | map(object) | {} | Secret Manager references |
| `invoker_members` | list(string) | [] | IAM members with invoke permission |
| `labels` | map(string) | {} | Resource labels |
| `vpc_connector` | string | null | VPC connector name |

### Firestore Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_id` | string | — | GCP project ID (required) |
| `location` | string | — | Database location (required) |
| `database_id` | string | "(default)" | Firestore database ID |
| `delete_protection` | bool | true | Prevent accidental deletion |
| `point_in_time_recovery` | bool | true | Enable PITR |

### Secret Manager Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_id` | string | — | GCP project ID (required) |
| `secrets` | map(object) | {} | Secret definitions |
| `accessors` | list(string) | [] | Service accounts with access |

### Pub/Sub Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_id` | string | — | GCP project ID (required) |
| `topics` | list(string) | [] | Topic names to create |
| `subscriptions` | map(object) | {} | Subscription configurations |
| `dead_letter_topic` | string | null | Default dead letter topic |

### IAM Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_id` | string | — | GCP project ID (required) |
| `service_accounts` | map(object) | {} | Service account definitions |
| `bindings` | list(object) | [] | IAM role bindings |

### Monitoring Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_id` | string | — | GCP project ID (required) |
| `service_name` | string | — | Service name to monitor (required) |
| `service_location` | string | — | Service region (required) |
| `alert_email` | string | null | Email for alert notifications |
| `latency_threshold_ms` | number | 2000 | P99 latency alert threshold |
| `error_rate_threshold` | number | 5 | Error rate alert threshold (%) |
| `cpu_threshold` | number | 80 | CPU utilization alert threshold (%) |

---

## Security Model

### Defense in Depth

```
┌─────────────────────────────────────────────────────────────────────┐
│ Layer 1: Network                                                     │
│ - Private ingress (internal-only) by default                        │
│ - VPC Service Controls compatible                                   │
│ - Cloud Armor for DDoS protection (optional)                        │
├─────────────────────────────────────────────────────────────────────┤
│ Layer 2: Identity                                                    │
│ - Service account per MCP server                                    │
│ - Least privilege IAM bindings                                      │
│ - Workload Identity for GKE (if applicable)                       │
├─────────────────────────────────────────────────────────────────────┤
│ Layer 3: Secrets                                                     │
│ - Secret Manager for all credentials                                │
│ - No secrets in Terraform state                                     │
│ - Automatic rotation support                                        │
├─────────────────────────────────────────────────────────────────────┤
│ Layer 4: Data                                                        │
│ - Firestore encryption at rest                                      │
│ - TLS in transit                                                    │
│ - PII redaction in logs                                             │
└─────────────────────────────────────────────────────────────────────┘
```

### IAM Best Practices

1. **One service account per MCP server** — isolation and auditability
2. **Least privilege** — only grant required permissions
3. **No user-managed service account keys** — use Workload Identity
4. **Regular access reviews** — audit IAM bindings quarterly

### Secret Management

```hcl
# Define secrets
secrets = {
  api-key = {
    secret_id = "mcp-api-key"
  }
}

# Grant access
accessors = [
  module.iam.service_accounts["mcp-sa"].email
]
```

**Production Pattern:** Create secrets manually after `terraform apply`:

```bash
echo -n "your-api-key" | gcloud secrets versions add mcp-api-key --data-file=-
```

---

## Observability

### Cloud Monitoring Dashboard

The monitoring module creates a dashboard with:

- **Request rate** — requests per second
- **Latency** — p50, p95, p99
- **Error rate** — percentage of 5xx responses
- **Instance count** — current and max instances
- **CPU and memory** — utilization percentages
- **Pub/Sub metrics** — backlog, ack latency

### Alert Policies

Default alerts:

| Alert | Condition | Severity |
|-------|-----------|----------|
| High latency | p99 > 2000ms for 5m | Warning |
| High error rate | 5xx > 5% for 5m | Critical |
| High CPU | CPU > 80% for 5m | Warning |
| Low instance count | instances < min for 10m | Warning |

### Structured Logging

All logs are structured JSON with:

```json
{
  "timestamp": "2026-04-15T23:00:00Z",
  "service": "my-mcp-server",
  "severity": "INFO",
  "message": "Request processed",
  "httpRequest": {
    "requestMethod": "POST",
    "requestUrl": "/mcp",
    "status": 200,
    "latency": "123ms"
  },
  "logging.googleapis.com/sourceLocation": {
    "file": "src/handler.ts",
    "line": "42"
  }
}
```

---

## Cost Optimization

### Right-Sizing

| Workload | CPU | Memory | Min/Max Instances |
|----------|-----|--------|-------------------|
| Low-traffic dev | 250m | 256Mi | 0/1 |
| Medium traffic | 500m | 512Mi | 0/5 |
| High traffic | 1000m | 1024Mi | 1/20 |

### Cost Estimation

```
Cloud Run: $0.000025 per vCPU-second + $0.0000025 per GiB-second
Firestore: $0.036 per GB stored + $0.06 per 100k reads + $0.18 per 100k writes
Secret Manager: $0.06 per secret per month + $0.03 per 10k accesses
Pub/Sub: $0.04 per million messages
```

**Example monthly cost for medium traffic:**
- Cloud Run: ~$15 (1M requests, 500ms avg)
- Firestore: ~$5 (1GB storage, 1M reads, 500k writes)
- Secret Manager: ~$1 (5 secrets)
- Pub/Sub: ~$4 (100k messages)
- **Total: ~$25/month**

### Cost Controls

```hcl
# Limit max instances to control costs
max_instances = 10

# Use scale-to-zero for dev
min_instances = 0

# Set CPU to minimum for cost savings
cpu = "250m"
```

---

## Integration with Multi-Agent Systems

### Service-to-Service Authentication

```hcl
# Grant orchestrator permission to invoke MCP server
resource "google_cloud_run_v2_service_iam_member" "orchestrator_invoker" {
  name     = module.mcp_cloudrun.service_name
  location = module.mcp_cloudrun.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${module.orchestrator.service_account_email}"
}
```

### Pub/Sub Integration

```hcl
# MCP server subscribes to task topic
resource "google_pubsub_subscription" "mcp_tasks" {
  name  = "mcp-tasks-sub"
  topic = "mcp-tasks"

  push_config {
    push_endpoint = module.mcp_cloudrun.service_url

    oidc_token {
      service_account_email = module.iam.service_accounts["pubsub-sa"].email
    }
  }

  ack_deadline_seconds = 30
}
```

---

## Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|---------|
| Cold start latency | Scale-to-zero | Set `min_instances = 1` |
| 500 errors | Missing secrets | Verify Secret Manager access |
| High latency | Insufficient resources | Increase CPU/memory |
| Permission denied | IAM misconfiguration | Check service account roles |
| Firestore timeout | Network issues | Verify VPC connectivity |

### Debug Commands

```bash
# Check Cloud Run logs
gcloud run services logs read my-mcp-server --limit 50

# Test service directly
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" $SERVICE_URL/health

# Check Firestore connectivity
gcloud firestore documents list --database "(default)"

# Verify Secret Manager access
gcloud secrets versions access latest --secret=mcp-api-key

# Check Pub/Sub backlog
gcloud pubsub subscriptions seek --subscription=mcp-tasks-sub --time=2024-01-01T00:00:00Z
```

---

## Checklist: Production Readiness

Before deploying to production:

- [ ] All secrets created in Secret Manager (not in Terraform)
- [ ] Service accounts configured with least privilege
- [ ] Cloud Run service set to internal-only ingress
- [ ] Firestore delete protection enabled
- [ ] Monitoring alerts configured with appropriate thresholds
- [ ] Cost controls in place (max instances, budget alerts)
- [ ] VPC connector configured for private network access
- [ ] Container image pinned to digest (not tag)
- [ ] Remote state configured with locking
- [ ] CI/CD pipeline validates Terraform changes
- [ ] Disaster recovery plan documented

---

## References

- **ARCHITECTURE.md** — System design deep dive
- **DEV_PLAN.md** — Development checklist
- **README.md** — Quick start and module reference
- **Cloud Run Documentation** — https://cloud.google.com/run/docs
- **Terraform Google Provider** — https://registry.terraform.io/providers/hashicorp/google