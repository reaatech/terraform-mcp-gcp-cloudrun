locals {
  common_labels = {
    environment = var.environment
    managed-by  = "terraform"
    project     = var.project_id
  }

  mcp_sa_email  = module.iam.service_account_emails["mcp-sa"]
  mcp_sa_member = "serviceAccount:${local.mcp_sa_email}"
}

# IAM Module - Create service accounts
module "iam" {
  source = "../../modules/iam"

  project_id = var.project_id

  service_accounts = {
    mcp-sa = {
      account_id   = "mcp-${var.environment}-sa"
      display_name = "Service account for MCP Cloud Run (${var.environment})"
      description  = "Service account for MCP servers deployed on Cloud Run in ${var.environment} environment"
    }
  }

  bindings = []
}

# Grant Firestore access to MCP service account
resource "google_project_iam_member" "firestore_access" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = local.mcp_sa_member
}

# Grant Cloud Trace access for distributed tracing
resource "google_project_iam_member" "trace_access" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = local.mcp_sa_member
}

# Firestore Module - Session state persistence
module "firestore" {
  source = "../../modules/firestore"

  project_id             = var.project_id
  database_id            = var.firestore_database_id
  location               = var.firestore_location
  delete_protection      = true
  point_in_time_recovery = true
}

# Secret Manager Module - API keys and credentials
module "secrets" {
  source = "../../modules/secrets"

  project_id = var.project_id
  secrets    = var.secrets
  accessors  = [local.mcp_sa_member]
}

# Cloud Run Module - Deploy MCP servers
module "cloud_run" {
  for_each = { for server in var.mcp_servers : server.name => server }

  source = "../../modules/cloud-run"

  name                  = each.value.name
  region                = var.region
  project_id            = var.project_id
  image                 = each.value.image
  service_account_email = local.mcp_sa_email

  min_instances = 1
  max_instances = 20

  cpu             = "2000m"
  memory          = "2048Mi"
  timeout_seconds = 120
  concurrency     = 80

  ingress               = "internal"
  allow_unauthenticated = false

  env_vars = {
    ENVIRONMENT  = var.environment
    LOG_LEVEL    = "INFO"
    FIRESTORE_DB = module.firestore.database_id
  }

  secret_env_vars = {
    for k, v in var.secrets : k => {
      secret  = v.secret_id
      version = "latest"
    }
  }

  labels = local.common_labels

  vpc_connector   = var.vpc_connector
  invoker_members = []
}

# Pub/Sub Module - Async task distribution (optional)
module "pubsub" {
  source = "../../modules/pubsub"

  count = var.enable_pubsub ? 1 : 0

  project_id = var.project_id
  topics     = distinct(concat(var.pubsub_topics, [for s in var.mcp_servers : "${s.name}-tasks"]))

  subscriptions = {
    for server in var.mcp_servers : "${server.name}-tasks" => {
      topic                     = "${server.name}-tasks"
      push_endpoint             = module.cloud_run[server.name].service_url
      push_service_account      = local.mcp_sa_email
      ack_deadline_seconds      = 30
      message_retention_seconds = 604800
      max_delivery_attempts     = 5
      dead_letter_topic         = "${server.name}-dlq"
    }
  }

  dead_letter_topic = "mcp-dlq"
}

# Monitoring Module - one instance per MCP service
module "monitoring" {
  source = "../../modules/monitoring"

  for_each = { for server in var.mcp_servers : server.name => server }

  project_id       = var.project_id
  service_name     = each.value.name
  service_location = var.region
  alert_email      = var.alert_email

  latency_threshold_ms      = 2000
  error_rate_rps            = 1
  cpu_utilization_threshold = 0.8
}
