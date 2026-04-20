variable "name" {
  description = "Name of the Cloud Run service"
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud Run service"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "image" {
  description = "Container image URI for the Cloud Run service"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for the Cloud Run service"
  type        = string
}

variable "min_instances" {
  description = "Minimum number of instances (0 for scale-to-zero)"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 10
}

variable "cpu" {
  description = "CPU limit for the Cloud Run service (e.g., '1000m')"
  type        = string
  default     = "1000m"
}

variable "memory" {
  description = "Memory limit for the Cloud Run service (e.g., '512Mi')"
  type        = string
  default     = "512Mi"
}

variable "timeout_seconds" {
  description = "Request timeout in seconds"
  type        = number
  default     = 60
}

variable "concurrency" {
  description = "Maximum concurrent requests per instance"
  type        = number
  default     = 80
}

variable "container_port" {
  description = "Container port the MCP server listens on. Set to null to use the Cloud Run default of 8080 (unset on the resource)."
  type        = number
  default     = 8080
}

variable "ingress" {
  description = "Ingress setting for the Cloud Run service"
  type        = string
  default     = "internal-and-cloud-load-balancing"

  validation {
    condition     = contains(["INGRESS_TRAFFIC_ALL", "INGRESS_TRAFFIC_INTERNAL_ONLY", "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER", "all", "internal", "internal-and-cloud-load-balancing", "internal-load-balancing"], var.ingress)
    error_message = "Ingress must be a valid Cloud Run v2 ingress value. Accepted: INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY, INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER (or their legacy equivalents: all, internal, internal-and-cloud-load-balancing, internal-load-balancing)."
  }
}

variable "env_vars" {
  description = "Plain environment variables for the Cloud Run service"
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Secret Manager references for environment variables"
  type = map(object({
    secret  = string
    version = string
  }))
  default = {}
}

variable "invoker_members" {
  description = "List of IAM members with invoke permission (e.g. 'serviceAccount:sa@project.iam.gserviceaccount.com')"
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Resource labels for the Cloud Run service"
  type        = map(string)
  default     = {}
}

variable "vpc_connector" {
  description = "Optional VPC connector name for private network access"
  type        = string
  default     = null
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated invocations"
  type        = bool
  default     = false
}

variable "enable_http_probes" {
  description = "Create startup and liveness HTTP probes hitting health_check_path on container_port. Disable for MCP servers that don't speak HTTP health checks."
  type        = bool
  default     = true
}

variable "health_check_path" {
  description = "HTTP path used by startup and liveness probes when enable_http_probes is true"
  type        = string
  default     = "/health"
}
