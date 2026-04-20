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

variable "alert_email" {
  description = "Email address for monitoring alerts"
  type        = string
  default     = null
}

variable "secrets" {
  description = "Map of secret definitions"
  type = map(object({
    secret_id = string
    labels    = optional(map(string), {})
  }))
  default = {}
}
