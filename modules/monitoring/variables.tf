variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "service_name" {
  description = "Name of the Cloud Run service to monitor"
  type        = string
}

variable "service_location" {
  description = "Region of the Cloud Run service"
  type        = string
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = null
}

variable "latency_threshold_ms" {
  description = "P99 latency alert threshold in milliseconds"
  type        = number
  default     = 2000
}

variable "error_rate_rps" {
  description = "5xx error rate alert threshold in requests-per-second (summed across the service)"
  type        = number
  default     = 1
}

variable "cpu_utilization_threshold" {
  description = "CPU utilization alert threshold as a fraction in [0,1] (e.g. 0.8 = 80%). Cloud Run exposes container/cpu/utilizations as a distribution in [0,1]."
  type        = number
  default     = 0.8

  validation {
    condition     = var.cpu_utilization_threshold > 0 && var.cpu_utilization_threshold <= 1
    error_message = "cpu_utilization_threshold must be a fraction in (0,1], e.g. 0.8 for 80%."
  }
}
