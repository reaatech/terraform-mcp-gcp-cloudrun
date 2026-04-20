output "orchestrator_url" {
  description = "The URL of the orchestrator Cloud Run service"
  value       = module.orchestrator.service_url
}

output "service_urls" {
  description = "Map of all service URLs"
  value = merge(
    { orchestrator = module.orchestrator.service_url },
    { for name, agent in module.agents : "agent-${name}" => agent.service_url }
  )
}

output "service_accounts" {
  description = "Map of service account emails"
  value       = module.iam.service_account_emails
}

output "firestore_database" {
  description = "Firestore database ID"
  value       = module.firestore.database_id
}

output "pubsub_topics" {
  description = "Pub/Sub topic IDs"
  value       = module.pubsub.topic_ids
}

output "pubsub_subscriptions" {
  description = "Pub/Sub subscription IDs"
  value       = module.pubsub.subscription_ids
}

output "monitoring_dashboard_urls" {
  description = "Map of service name to Cloud Monitoring dashboard URL"
  value = merge(
    { orchestrator = module.monitoring_orchestrator.dashboard_url },
    { for k, m in module.monitoring_agents : k => m.dashboard_url }
  )
}
