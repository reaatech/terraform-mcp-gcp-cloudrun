# Multi-Service Deployment

## Capability
Deploy orchestrator and agent MCP servers with Pub/Sub for async task distribution. Orchestrator dispatches tasks to agents via message queues.

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

## Terraform Resources
| Resource | Purpose | Key Configuration |
|----------|---------|-------------------|
| `google_pubsub_topic` | Task distribution | Topics for tasks and results |
| `google_pubsub_subscription` | Message consumption | Push endpoints to agent services |

## Usage Examples

### Orchestrator + Agents
```hcl
# Orchestrator service
module "orchestrator" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/cloud-run"

  name                = "orchestrator"
  region              = "us-central1"
  project_id          = "my-project"
  image               = "gcr.io/my-project/orchestrator:latest"
  service_account_email = module.iam.service_account_emails["orchestrator-sa"]

  env_vars = {
    PUBSUB_TASKS   = "orchestrator-tasks"
    PUBSUB_RESULTS = "agent-results"
  }
}

# Agent services
module "agents" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/cloud-run"

  for_each = { for agent in var.agents : agent.name => agent }

  name                = each.value.name
  region              = "us-central1"
  project_id          = "my-project"
  image               = each.value.image
  service_account_email = module.iam.service_account_emails["agent-sa"]

  env_vars = {
    PUBSUB_TASKS   = "orchestrator-tasks"
    PUBSUB_RESULTS = "agent-results"
    AGENT_NAME     = each.value.name
  }
}
```

## Service-to-Service Authentication
```hcl
# Grant orchestrator permission to invoke agents
resource "google_cloud_run_v2_service_iam_member" "orchestrator_to_agents" {
  for_each = toset(["agent-a", "agent-b"])

  name     = each.value
  location = "us-central1"
  role     = "roles/run.invoker"
  member   = "serviceAccount:${module.iam.service_account_emails["orchestrator-sa"]}"
}
```

## Error Handling
- **Agent not receiving tasks**: Verify Pub/Sub subscription push endpoint
- **Task ordering issues**: Use session_id in message for ordering guarantees
- **Agent scaling issues**: Adjust min_instances/max_instances for workload

## Security Considerations
- Use separate service accounts for orchestrator and agents
- Grant only `roles/run.invoker` for service-to-service calls
- Use internal ingress for agent services (orchestrator only)
- Rotate Pub/Sub credentials regularly
- Monitor agent invocation patterns for anomalies