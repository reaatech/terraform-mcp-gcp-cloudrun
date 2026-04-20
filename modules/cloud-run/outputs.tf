output "service_url" {
  description = "The URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.uri
}

output "service_name" {
  description = "The name of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.name
}

output "service_account_email" {
  description = "The service account email used by the Cloud Run service"
  value       = var.service_account_email
}

output "service_location" {
  description = "The region where the Cloud Run service is deployed"
  value       = var.region
}

output "service_id" {
  description = "The ID of the Cloud Run service"
  value       = google_cloud_run_v2_service.this.id
}
