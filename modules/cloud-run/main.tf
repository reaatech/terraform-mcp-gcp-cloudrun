terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

locals {
  labels = merge(
    {
      "managed-by" = "terraform"
      "module"     = "cloud-run"
    },
    var.labels
  )
}

resource "google_cloud_run_v2_service" "this" {
  name     = var.name
  location = var.region
  project  = var.project_id
  ingress  = var.ingress

  description = "MCP server deployed on Cloud Run"

  labels = local.labels

  template {
    service_account = var.service_account_email
    timeout         = "${var.timeout_seconds}s"

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    dynamic "vpc_access" {
      for_each = var.vpc_connector != null ? [1] : []
      content {
        connector = var.vpc_connector
      }
    }

    containers {
      image = var.image

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      dynamic "ports" {
        for_each = var.container_port != null ? [var.container_port] : []
        content {
          container_port = ports.value
        }
      }

      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret
              version = env.value.version
            }
          }
        }
      }

      dynamic "startup_probe" {
        for_each = var.enable_http_probes ? [1] : []
        content {
          failure_threshold     = 6
          period_seconds        = 10
          initial_delay_seconds = 10
          timeout_seconds       = 10

          http_get {
            path = var.health_check_path
            port = var.container_port
          }
        }
      }

      dynamic "liveness_probe" {
        for_each = var.enable_http_probes ? [1] : []
        content {
          failure_threshold     = 3
          period_seconds        = 10
          initial_delay_seconds = 20
          timeout_seconds       = 5

          http_get {
            path = var.health_check_path
            port = var.container_port
          }
        }
      }
    }

    max_instance_request_concurrency = var.concurrency
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# IAM binding for unauthenticated access (if enabled)
resource "google_cloud_run_v2_service_iam_member" "unauthenticated" {
  count = var.allow_unauthenticated ? 1 : 0

  name     = google_cloud_run_v2_service.this.name
  location = google_cloud_run_v2_service.this.location
  project  = google_cloud_run_v2_service.this.project
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# IAM bindings for specific invoker members
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  for_each = toset(var.invoker_members)

  name     = google_cloud_run_v2_service.this.name
  location = google_cloud_run_v2_service.this.location
  project  = google_cloud_run_v2_service.this.project
  role     = "roles/run.invoker"
  member   = each.value
}
