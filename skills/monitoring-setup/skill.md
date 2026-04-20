# Monitoring Setup

## Capability
Deploy Cloud Monitoring dashboards and alert policies for MCP server observability including latency, error rate, and CPU utilization.

## Terraform Resources
| Resource | Purpose | Key Configuration |
|----------|---------|-------------------|
| `google_monitoring_dashboard` | Monitoring dashboard | Grid layout with 6 chart types |
| `google_monitoring_alert_policy` | Alert policies | Latency, error rate, CPU thresholds |
| `google_monitoring_notification_channel` | Email notifications | `alert_email` variable |

## Usage Examples

### Basic Monitoring
```hcl
module "monitoring" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/monitoring"

  project_id       = "my-project"
  service_name    = "my-mcp-server"
  service_location = "us-central1"
}
```

### Monitoring with Alerts
```hcl
module "monitoring" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/monitoring"

  project_id            = "my-project"
  service_name          = "my-mcp-server"
  service_location      = "us-central1"
  alert_email           = "team@example.com"

  latency_threshold_ms = 2000
  error_rate_threshold = 5
  cpu_threshold       = 80
}
```

## Dashboard Charts
- **Request Rate** — Requests per second
- **Latency (p50, p95, p99)** — Response time percentiles
- **Instance Count** — Current and max instances
- **CPU Utilization** — Container CPU usage percentage
- **Memory Utilization** — Container memory usage percentage
- **Error Rate** — 5xx responses per second

## Error Handling
- **Dashboard creation fails**: Ensure Monitoring API is enabled
- **Alert policy fails**: Verify notification channel is valid
- **Missing metrics**: Cloud Run needs ~1 minute to emit initial metrics

## Security Considerations
- Configure `alert_email` for production alerts
- Set appropriate thresholds to avoid alert fatigue
- Use notification rate limiting to prevent spam
- Review alert policies quarterly

## Outputs
| Output | Description |
|--------|-------------|
| `dashboard_url` | URL to Cloud Monitoring dashboard |
| `alert_policies` | Map of alert policy names to IDs |
| `notification_channel_id` | Email notification channel ID |