variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "topics" {
  description = "List of Pub/Sub topic names to create"
  type        = list(string)
  default     = []
}

variable "subscriptions" {
  description = "Map of subscription configurations"
  type = map(object({
    topic                     = string
    push_endpoint             = optional(string)
    push_service_account      = optional(string)
    ack_deadline_seconds      = optional(number, 30)
    message_retention_seconds = optional(number, 604800) # 7 days
    max_delivery_attempts     = optional(number, 5)
    dead_letter_topic         = optional(string)
  }))
  default = {}
}

variable "dead_letter_topic" {
  description = "Optional default dead letter topic name"
  type        = string
  default     = null
}
