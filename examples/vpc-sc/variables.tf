variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "mcp_server_name" {
  description = "Name of the MCP server"
  type        = string
  default     = "my-mcp-server"
}

variable "mcp_server_image" {
  description = "Container image for the MCP server"
  type        = string
  default     = "gcr.io/google-samples/hello-app:1.0"
}

variable "vpc_connector" {
  description = "VPC Access connector name"
  type        = string
  default     = null
}

variable "firestore_database_id" {
  description = "Firestore database ID"
  type        = string
  default     = "(default)"
}

variable "firestore_location" {
  description = "Firestore database location"
  type        = string
  default     = "us-central"
}

variable "delete_protection" {
  description = "Enable Firestore delete protection"
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address for monitoring alerts"
  type        = string
  default     = null
}

variable "invoker_members" {
  description = "List of members allowed to invoke the Cloud Run service"
  type        = list(string)
  default     = []
}
