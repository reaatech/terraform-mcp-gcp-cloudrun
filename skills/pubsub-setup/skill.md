# Pub/Sub Setup

## Capability
Create Pub/Sub topics and subscriptions with push endpoints, dead-letter queues, and OIDC authentication.

## Terraform Resources
| Resource | Purpose | Key Configuration |
|----------|---------|-------------------|
| `google_pubsub_topic` | Topic creation | Dead-letter topic support |
| `google_pubsub_subscription` | Subscription management | `push_config`, `dead_letter_policy` |

## Usage Examples

### Basic Topics
```hcl
module "pubsub" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/pubsub"

  project_id = "my-project"
  topics     = ["mcp-tasks", "mcp-results"]
}
```

### Subscription with Push and Dead-Letter
```hcl
module "pubsub" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/pubsub"

  project_id       = "my-project"
  topics           = ["mcp-tasks"]
  dead_letter_topic = "mcp-dlq"

  subscriptions = {
    mcp-tasks-sub = {
      topic                   = "mcp-tasks"
      push_endpoint           = "https://my-service.run.app/mcp"
      push_service_account    = "sa@my-project.iam.gserviceaccount.com"
      ack_deadline_seconds    = 30
      message_retention_seconds = 604800  # 7 days
      max_delivery_attempts   = 5
      dead_letter_topic       = "mcp-dlq"
    }
  }
}
```

## Error Handling
- **Topic creation fails**: Ensure Pub/Sub API is enabled
- **Push endpoint unreachable**: Verify Cloud Run service is deployed and accessible
- **Dead-letter topic missing**: Create DLQ topic before referencing in subscription

## Security Considerations
- Always configure dead-letter queues for failed message handling
- Use OIDC tokens in push subscriptions for authentication
- Set reasonable `ack_deadline_seconds` for long-running message processing
- Configure `message_retention_seconds` for disaster recovery
- Limit `max_delivery_attempts` to prevent infinite retry loops

## Outputs
| Output | Description |
|--------|-------------|
| `topic_names` | Set of created topic names |
| `subscription_names` | Map of subscription names |