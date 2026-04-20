output "secret_names" {
  description = "Map of secret keys to their resource names"
  value = {
    for k, v in google_secret_manager_secret.this : k => v.id
  }
}

output "secret_ids" {
  description = "Map of secret keys to their secret IDs"
  value = {
    for k, v in google_secret_manager_secret.this : k => v.secret_id
  }
}
