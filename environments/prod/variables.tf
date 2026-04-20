variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "mcp_servers" {
  description = "List of MCP server configurations"
  type = list(object({
    name  = string
    image = string
  }))
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
}

variable "enable_pubsub" {
  description = "Enable Pub/Sub for async task distribution"
  type        = bool
  default     = true
}

variable "pubsub_topics" {
  description = "List of Pub/Sub topic names to create in addition to per-service tasks topics"
  type        = list(string)
  default     = ["mcp-tasks", "mcp-results", "mcp-events"]
}

variable "secrets" {
  description = "Map of secret definitions"
  type = map(object({
    secret_id = string
    labels    = optional(map(string), {})
  }))
  default = {}
}

variable "vpc_connector" {
  description = "Optional VPC connector name for private network access"
  type        = string
  default     = null
}
