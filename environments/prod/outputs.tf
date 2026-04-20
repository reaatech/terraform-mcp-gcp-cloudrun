output "cloud_run_services" {
  description = "Map of Cloud Run service URLs"
  value = {
    for name, service in module.cloud_run : name => {
      url  = service.service_url
      name = service.service_name
    }
  }
}

output "service_account_email" {
  description = "Service account email for MCP servers"
  value       = module.iam.service_account_emails["mcp-sa"]
}

output "firestore_database" {
  description = "Firestore database ID"
  value       = module.firestore.database_id
}

output "monitoring_dashboard_urls" {
  description = "Map of service name to Cloud Monitoring dashboard URL"
  value       = { for k, m in module.monitoring : k => m.dashboard_url }
}

output "pubsub_topics" {
  description = "Pub/Sub topic IDs (if enabled)"
  value       = try(module.pubsub[0].topic_ids, {})
}
