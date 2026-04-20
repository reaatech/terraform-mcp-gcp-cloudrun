terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# Firestore Native database
resource "google_firestore_database" "this" {
  name                              = var.database_id
  location_id                       = var.location
  type                              = "FIRESTORE_NATIVE"
  project                           = var.project_id
  delete_protection_state           = var.delete_protection ? "DELETE_PROTECTION_ENABLED" : "DELETE_PROTECTION_DISABLED"
  point_in_time_recovery_enablement = var.point_in_time_recovery ? "POINT_IN_TIME_RECOVERY_ENABLED" : "POINT_IN_TIME_RECOVERY_DISABLED"
}

# Composite index for session queries by user_id and status
resource "google_firestore_index" "session_user_status" {
  count = var.create_session_indexes ? 1 : 0

  database    = google_firestore_database.this.name
  collection  = "sessions"
  query_scope = "COLLECTION"
  project     = var.project_id

  fields {
    field_path = "user_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "status"
    order      = "ASCENDING"
  }

  fields {
    field_path = "ttl"
    order      = "ASCENDING"
  }
}

# Composite index for session lookup by session_id
resource "google_firestore_index" "session_lookup" {
  count = var.create_session_indexes ? 1 : 0

  database    = google_firestore_database.this.name
  collection  = "sessions"
  query_scope = "COLLECTION"
  project     = var.project_id

  fields {
    field_path = "session_id"
    order      = "ASCENDING"
  }

  fields {
    field_path = "ttl"
    order      = "ASCENDING"
  }
}
