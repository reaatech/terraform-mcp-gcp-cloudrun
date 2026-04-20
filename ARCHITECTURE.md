# terraform-mcp-gcp-cloudrun — Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Client Layer                                │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                  │
│  │  MCP Client │    │  agent-mesh │    │  Direct API │                  │
│  │  (Claude)   │    │  Orchestrator│   │  Consumer   │                  │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                  │
│         │                   │                   │                         │
│         └───────────────────┼───────────────────┘                         │
│                             │ HTTP/MCP                                       │
└─────────────────────────────┼─────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Cloud Run Service                                │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                    MCP Server Container                           │   │
│  │                                                                   │   │
│  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐           │   │
│  │  │   MCP       │───▶│   Session   │───▶│    Tool     │           │   │
│  │  │  Protocol   │    │  Manager    │    │  Executor   │           │   │
│  │  │  Handler    │    │             │    │             │           │   │
│  │  └─────────────┘    └─────────────┘    └─────────────┘           │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  Config:                                                             │
│  - Min instances: 0 (scale to zero) or 1+ for low latency           │
│  - Max instances: 10-20 (configurable)                              │
│  - Memory: 512MB-2GB, CPU: 250m-2000m                               │
│  - Timeout: 60s (configurable)                                      │
│                                                                      │
│  Secrets: Secret Manager → mounted as env vars                       │
│  Observability: Cloud Monitoring + Cloud Logging                     │
└─────────────────────────────────────────────────────────────────────────┘
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       Cross-Cutting Concerns                             │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐       │
│  │    Firestore     │  │  Secret Manager  │  │     Pub/Sub      │       │
│  │  - Sessions      │  │  - API Keys      │  │  - Async Tasks   │       │
│  │  - State         │  │  - Tokens        │  │  - Events        │       │
│  │  - TTL           │  │  - Credentials   │  │  - DLQ           │       │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘       │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Design Principles

### 1. Stateless by Design
- No in-memory state shared across requests
- All session state persisted to Firestore
- Enables horizontal scaling on Cloud Run
- Zero-downtime deployments

### 2. Zero-Trust Security
- Service account per MCP server
- Least privilege IAM bindings
- Secret Manager for all credentials
- Private ingress by default

### 3. Observability First
- Structured JSON logging to Cloud Logging
- Cloud Monitoring metrics and dashboards
- Distributed tracing with Cloud Trace
- Alert policies for SLO monitoring

### 4. Cost Optimization
- Scale to zero when idle (dev)
- Right-size resources for workload
- Pub/Sub for async processing
- Budget alerts and cost controls

### 5. Production Ready
- Startup probes for cold start handling
- Circuit breakers for resilience
- Dead-letter queues for failure handling
- Point-in-time recovery for disaster recovery

---

## Component Deep Dive

### Cloud Run Service

The Cloud Run service hosts the MCP server container:

```hcl
resource "google_cloud_run_v2_service" "this" {
  name     = var.name
  location = var.region
  project  = var.project_id
  ingress  = var.ingress

  template {
    service_account = var.service_account_email
    timeout         = "${var.timeout_seconds}s"

    containers {
      image = var.image

      # Environment variables
      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret environment variables
      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret
              version = env.value.version
            }
          }
        }
      }

      # Resource limits
      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      # Startup probe (critical for MCP servers)
      startup_probe {
        failure_threshold     = 6
        period_seconds        = 10
        initial_delay_seconds = 10
        timeout_seconds       = 10

        http_get {
          path = "/health"
          port = 8080
        }
      }
    }

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }
  }
}
```

**Startup Probe Configuration:**
- **Initial delay**: 10s — gives the service time to start listening
- **Period**: 10s — check every 10 seconds
- **Failure threshold**: 6 — allow up to 60s for startup
- **Timeout**: 10s — each probe must complete within 10s

This extended startup time allows for:
1. Container initialization
2. Registry loading (if using agent-mesh patterns)
3. Circuit breaker state restoration from Firestore
4. Warm-up of LLM connections

### Firestore Database

Firestore provides session state persistence:

```hcl
resource "google_firestore_database" "this" {
  name                     = var.database_id
  location                 = var.location
  type                     = "FIRESTORE_NATIVE"
  delete_protection        = var.delete_protection
  point_in_time_recovery   = var.point_in_time_recovery
}
```

**Session Schema:**

```
sessions/{session_id}
├── user_id: string
├── status: "active" | "completed" | "abandoned"
├── ttl: timestamp (for automatic cleanup)
├── created_at: timestamp
├── updated_at: timestamp
├── turn_history: array
│   ├── { role: "user", content: string, timestamp: string }
│   └── { role: "agent", content: string, timestamp: string }
└── workflow_state: map<string, any>
```

**Composite Indexes:**

```hcl
resource "google_firestore_index" "session_lookup" {
  database   = google_firestore_database.this.name
  collection = "sessions"
  query_scope = "COLLECTION"

  fields {
    field_path = "user_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "status"
    order      = "ASCENDING"
  }

  fields {
    field_path = "ttl"
    order      = "ASCENDING"
  }
}
```

### Secret Manager Integration

All secrets are stored in Secret Manager:

```hcl
resource "google_secret_manager_secret" "this" {
  for_each = var.secrets

  secret_id = each.value.secret_id
  project   = var.project_id

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = var.accessors

  secret_id = google_secret_manager_secret.this[each.key].id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${each.value}"
}
```

**Secret Access Pattern:**

```hcl
# In the Cloud Run service
secret_env_vars = {
  API_KEY = {
    secret  = "mcp-api-key"
    version = "latest"
  }
}
```

The secret is mounted as an environment variable at runtime, never stored in Terraform state.

### Pub/Sub for Async Tasks

Pub/Sub enables async task distribution:

```hcl
resource "google_pubsub_topic" "tasks" {
  name = "mcp-tasks"
}

resource "google_pubsub_subscription" "tasks" {
  name  = "mcp-tasks-sub"
  topic = google_pubsub_topic.tasks.id

  push_config {
    push_endpoint = google_cloud_run_v2_service.this.url

    oidc_token {
      service_account_email = var.push_service_account
    }
  }

  ack_deadline_seconds     = 30
  message_retention_seconds = 604800  # 7 days

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dlq.id
    max_delivery_attempts = 5
  }
}
```

**Message Schema:**

```json
{
  "data": {
    "task_id": "uuid",
    "task_type": "process_request",
    "payload": { /* task-specific data */ },
    "callback_url": "https://orchestrator.example.com/callback"
  },
  "attributes": {
    "priority": "normal",
    "timeout_ms": "30000"
  }
}
```

---

## Security Model

### Defense in Depth

```
┌─────────────────────────────────────────────────────────────────────┐
│ Layer 1: Network                                                     │
│ - Private ingress (internal-only) by default                        │
│ - VPC Service Controls compatible                                   │
│ - Cloud Armor for DDoS protection (optional)                        │
│ - TLS 1.3 enforced                                                  │
├─────────────────────────────────────────────────────────────────────┤
│ Layer 2: Identity                                                    │
│ - Service account per MCP server                                    │
│ - Least privilege IAM bindings                                      │
│ - Workload Identity for GKE (if applicable)                         │
│ - No user-managed service account keys                              │
├─────────────────────────────────────────────────────────────────────┤
│ Layer 3: Secrets                                                     │
│ - Secret Manager for all credentials                                │
│ - No secrets in Terraform state                                     │
│ - Automatic rotation support                                        │
│ - Access logging enabled                                            │
├─────────────────────────────────────────────────────────────────────┤
│ Layer 4: Data                                                        │
│ - Firestore encryption at rest (CMEK optional)                      │
│ - TLS in transit                                                    │
│ - PII redaction in logs                                             │
│ - Point-in-time recovery for disaster recovery                      │
└─────────────────────────────────────────────────────────────────────┘
```

### IAM Bindings

Each MCP server gets a dedicated service account with minimal permissions:

```hcl
# Service account for MCP server
resource "google_service_account" "mcp" {
  account_id   = "${var.name}-sa"
  display_name = "Service account for ${var.name}"
}

# Firestore access
resource "google_project_iam_member" "firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.mcp.email}"
}

# Secret Manager access (only to specific secrets)
resource "google_secret_manager_secret_iam_member" "api_key" {
  secret_id = "mcp-api-key"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.mcp.email}"
}

# Pub/Sub access
resource "google_pubsub_subscription_iam_member" "tasks" {
  subscription = google_pubsub_subscription.tasks.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${google_service_account.mcp.email}"
}
```

---

## Data Flow

### Synchronous Request Flow

```
1. Client sends MCP request to Cloud Run
        │
2. Cloud Run routes to available instance
        │
3. MCP server processes request:
   - Validate authentication
   - Load session from Firestore (if session_id provided)
   - Execute tool or handle message
   - Update session state
        │
4. Response sent to client
        │
5. Cloud Logging captures structured log
        │
6. Cloud Monitoring updates metrics
```

### Asynchronous Task Flow

```
1. Producer publishes message to Pub/Sub topic
        │
2. Pub/Sub delivers to subscription push endpoint
        │
3. Cloud Run instance receives push request
        │
4. MCP server processes task:
   - Validate OIDC token from Pub/Sub
   - Execute task
   - Send callback to producer (if callback_url provided)
        │
5. Acknowledge message to Pub/Sub
        │
6. On failure: retry up to max_delivery_attempts, then DLQ
```

### Session Management Flow

```
1. New session created:
   - Generate UUID for session_id
   - Create Firestore document with TTL = now + 30m
   - Return session_id to client

2. Active session:
   - Lookup session by session_id
   - Append turn to turn_history (arrayUnion)
   - Refresh TTL = now + 30m
   - Update workflow_state

3. Session cleanup:
   - Firestore TTL policy automatically deletes expired documents
   - No manual cleanup required
```

---

## Observability

### Cloud Monitoring Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `run.googleapis.com/request_count` | Counter | Total requests |
| `run.googleapis.com/request_latencies` | Histogram | Request latency |
| `run.googleapis.com/container/instance_count` | Gauge | Active instances |
| `run.googleapis.com/container/memory/utilizations` | Gauge | Memory utilization |
| `run.googleapis.com/container/cpu/utilizations` | Gauge | CPU utilization |

### Cloud Logging

All logs are structured JSON:

```json
{
  "severity": "INFO",
  "time": "2026-04-15T23:00:00.000Z",
  "logging.googleapis.com/sourceLocation": {
    "file": "src/handler.ts",
    "line": "42",
    "function": "handleRequest"
  },
  "httpRequest": {
    "requestMethod": "POST",
    "requestUrl": "/mcp",
    "status": 200,
    "latency": "0.123s",
    "remoteIp": "10.0.0.1"
  },
  "message": "MCP request processed",
  "mcp": {
    "method": "tools/call",
    "tool": "handle_message",
    "duration_ms": 123,
    "session_id": "abc-123"
  }
}
```

### Alert Policies

```hcl
resource "google_monitoring_alert_policy" "high_latency" {
  display_name = "High Latency - ${var.name}"

  conditions {
    display_name = "P99 Latency > 2000ms"
    condition_threshold {
      filter          = "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = 2000
      duration        = "300s"
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}
```

---

## Deployment Patterns

### Blue/Green Deployment

```hcl
# Create new revision
resource "google_cloud_run_v2_service" "new" {
  name     = var.name
  location = var.region
  
  # Same config as current, but with new image
  template {
    containers {
      image = var.new_image
    }
  }
}

# Gradually shift traffic
resource "google_cloud_run_service_iam_binding" "traffic" {
  location = var.region
  name     = google_cloud_run_v2_service.new.name
  role     = "roles/run.invoker"
  
  # Use traffic splitting for gradual rollout
}
```

### Canary Deployment

```hcl
# Split traffic between revisions
traffic {
  type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  percent = 90  # 90% to latest
}

traffic {
  revision = google_cloud_run_v2_service.current.latest_revision
  percent  = 10  # 10% to current
}
```

---

## Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Cold start timeout | Startup probe fails | Increase probe threshold, set min_instances=1 |
| Firestore unavailable | Connection error | Retry with backoff, fail open for read operations |
| Secret Manager unavailable | Secret access error | Cache secrets locally, use default values |
| Pub/Sub delivery failure | Push endpoint error | Retry with exponential backoff, DLQ after max attempts |
| High memory usage | OOM kill | Increase memory limit, optimize code |
| High latency | P99 threshold exceeded | Scale up instances, optimize hot paths |
| Circuit breaker open | Failure threshold exceeded | Investigate root cause, manual reset if needed |

---

## Cost Model

### Pricing Components

| Component | Pricing | Example Monthly Cost |
|-----------|---------|---------------------|
| Cloud Run | $0.000025/vCPU-second + $0.0000025/GiB-second | $15 (1M requests) |
| Firestore | $0.036/GB stored + $0.06/100k reads + $0.18/100k writes | $5 |
| Secret Manager | $0.06/secret/month + $0.03/10k accesses | $1 |
| Pub/Sub | $0.04/million messages | $4 (100k messages) |
| Cloud Monitoring | Free tier + $0.025/metric/month | $5 |
| Cloud Logging | 50GB free + $0.50/GB | $10 |

**Total estimated monthly cost for medium traffic: ~$40**

### Cost Optimization Strategies

1. **Scale to zero** — Set `min_instances = 0` for dev environments
2. **Right-size resources** — Use smallest CPU/memory that meets SLOs
3. **Batch operations** — Use Pub/Sub for async processing
4. **Log sampling** — Sample debug logs in production
5. **Budget alerts** — Set up billing alerts at 50%, 75%, 90%

---

## References

- **AGENTS.md** — Agent deployment guide
- **DEV_PLAN.md** — Development checklist
- **README.md** — Quick start and module reference
- **Cloud Run Documentation** — https://cloud.google.com/run/docs
- **Firestore Documentation** — https://cloud.google.com/firestore/docs
- **Pub/Sub Documentation** — https://cloud.google.com/pubsub/docs
- **Secret Manager Documentation** — https://cloud.google.com/secret-manager/docs
