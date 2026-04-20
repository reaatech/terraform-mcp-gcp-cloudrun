output "mcp_server_url" {
  description = "The URL of the MCP server Cloud Run service"
  value       = module.cloud_run.service_url
}

output "mcp_server_name" {
  description = "The name of the MCP server Cloud Run service"
  value       = module.cloud_run.service_name
}

output "service_account_email" {
  description = "Service account email used by the MCP server"
  value       = module.iam.service_account_emails["mcp-sa"]
}

output "firestore_database" {
  description = "Firestore database ID"
  value       = module.firestore.database_id
}

output "monitoring_dashboard_url" {
  description = "Cloud Monitoring dashboard URL"
  value       = module.monitoring.dashboard_url
}
