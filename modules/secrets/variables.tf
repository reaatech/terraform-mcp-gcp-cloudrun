variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "secrets" {
  description = "Map of secret definitions"
  type = map(object({
    secret_id = string
    labels    = optional(map(string), {})
  }))
  default = {}
}

variable "accessors" {
  description = "Fully-qualified IAM members granted roles/secretmanager.secretAccessor on every secret (e.g. 'serviceAccount:sa@project.iam.gserviceaccount.com')"
  type        = list(string)
  default     = []
}
