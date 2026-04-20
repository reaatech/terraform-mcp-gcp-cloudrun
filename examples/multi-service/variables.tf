variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "orchestrator_image" {
  description = "Container image for the orchestrator"
  type        = string
  default     = "gcr.io/google-samples/hello-app:1.0"
}

variable "agents" {
  description = "List of agent configurations"
  type = list(object({
    name  = string
    image = string
  }))
  default = [
    { name = "agent-a", image = "gcr.io/google-samples/hello-app:2.0" }
  ]
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
