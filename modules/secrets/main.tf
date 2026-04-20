terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

# Create Secret Manager secrets
resource "google_secret_manager_secret" "this" {
  for_each = var.secrets

  secret_id = each.value.secret_id
  project   = var.project_id

  labels = merge(
    {
      "managed-by" = "terraform"
      "module"     = "secrets"
    },
    each.value.labels
  )

  replication {
    auto {}
  }
}

# Grant secret accessor role to specified IAM members.
# Each entry in var.accessors must be a fully-qualified IAM member string
# (e.g. "serviceAccount:sa@project.iam.gserviceaccount.com", "user:a@b.com", "group:...")
resource "google_secret_manager_secret_iam_member" "accessor" {
  for_each = {
    for pair in setproduct(keys(var.secrets), var.accessors) :
    join("|", pair) => {
      secret_key = pair[0]
      member     = pair[1]
    }
  }

  project   = var.project_id
  secret_id = google_secret_manager_secret.this[each.value.secret_key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member
}
