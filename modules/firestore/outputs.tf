output "database_id" {
  description = "Firestore database ID (the resource 'name' field, e.g. '(default)')"
  value       = google_firestore_database.this.name
}

output "database_name" {
  description = "Alias of database_id — kept for backward compatibility"
  value       = google_firestore_database.this.name
}

output "location" {
  description = "Database location"
  value       = google_firestore_database.this.location_id
}
