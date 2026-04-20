variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "service_accounts" {
  description = "Map of service account definitions"
  type = map(object({
    account_id   = string
    display_name = optional(string)
    description  = optional(string)
  }))
  default = {}
}

variable "bindings" {
  description = "List of IAM role bindings"
  type = list(object({
    member   = string
    role     = string
    service  = optional(string) # Optional service name for service-specific IAM
    location = optional(string) # Required when service is specified
  }))
  default = []
}
