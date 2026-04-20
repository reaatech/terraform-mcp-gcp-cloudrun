output "dashboard_url" {
  description = "URL to the Cloud Monitoring dashboard"
  value       = "https://console.cloud.google.com/monitoring/dashboards/builder/${google_monitoring_dashboard.mcp.id}?project=${var.project_id}"
}

output "alert_policies" {
  description = "Map of alert policy names to their IDs"
  value = {
    high_latency    = google_monitoring_alert_policy.high_latency.id
    high_error_rate = google_monitoring_alert_policy.high_error_rate.id
    high_cpu        = google_monitoring_alert_policy.high_cpu.id
  }
}

output "notification_channel_id" {
  description = "ID of the email notification channel"
  value       = try(google_monitoring_notification_channel.email[0].id, null)
}
