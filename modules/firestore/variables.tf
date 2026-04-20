variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "database_id" {
  description = "Firestore database ID (use \"(default)\" for default database)"
  type        = string
  default     = "(default)"
}

variable "location" {
  description = "Firestore database location (must match region)"
  type        = string
}

variable "delete_protection" {
  description = "Prevent accidental deletion of the database"
  type        = bool
  default     = true
}

variable "point_in_time_recovery" {
  description = "Enable point-in-time recovery for disaster recovery"
  type        = bool
  default     = true
}

variable "create_session_indexes" {
  description = "Create composite indexes for the 'sessions' collection (user_id+status+ttl and session_id+ttl). Set false if your MCP server uses a different schema."
  type        = bool
  default     = true
}
