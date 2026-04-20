output "service_account_emails" {
  description = "Map of service account names to their emails"
  value = {
    for k, v in google_service_account.this : k => v.email
  }
}

output "service_accounts" {
  description = "Map of service account details"
  value = {
    for k, v in google_service_account.this : k => {
      email     = v.email
      unique_id = v.unique_id
    }
  }
}
