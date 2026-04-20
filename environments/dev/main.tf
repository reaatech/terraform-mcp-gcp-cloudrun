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
  delete_protection      = var.environment != "dev"
  point_in_time_recovery = var.environment != "dev"
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

  min_instances = var.environment == "dev" ? 0 : 1
  max_instances = var.environment == "dev" ? 2 : 10

  cpu             = var.environment == "dev" ? "250m" : "1000m"
  memory          = var.environment == "dev" ? "256Mi" : "512Mi"
  timeout_seconds = 60
  concurrency     = 80

  # Dev defaults to public ingress so developers can curl the service directly.
  # Non-dev environments use internal + load-balancer ingress.
  ingress               = var.environment == "dev" ? "all" : "internal-and-cloud-load-balancing"
  allow_unauthenticated = var.environment == "dev"

  env_vars = {
    ENVIRONMENT  = var.environment
    LOG_LEVEL    = var.environment == "dev" ? "DEBUG" : "INFO"
    FIRESTORE_DB = module.firestore.database_id
  }

  secret_env_vars = {
    for k, v in var.secrets : k => {
      secret  = v.secret_id
      version = "latest"
    }
  }

  labels = local.common_labels

  invoker_members = []
}

# Pub/Sub Module - Async task distribution (optional)
module "pubsub" {
  source = "../../modules/pubsub"

  count = var.enable_pubsub ? 1 : 0

  project_id = var.project_id
  topics     = distinct(concat(var.pubsub_topics, [for s in var.mcp_servers : "${s.name}-tasks"]))

  subscriptions = length(var.mcp_servers) > 0 ? {
    for server in var.mcp_servers : "${server.name}-tasks" => {
      topic                     = "${server.name}-tasks"
      push_endpoint             = module.cloud_run[server.name].service_url
      push_service_account      = local.mcp_sa_email
      ack_deadline_seconds      = 30
      message_retention_seconds = 604800
      max_delivery_attempts     = 5
      dead_letter_topic         = "${server.name}-dlq"
    }
  } : {}

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

  latency_threshold_ms      = var.environment == "dev" ? 5000 : 2000
  error_rate_rps            = var.environment == "dev" ? 5 : 1
  cpu_utilization_threshold = var.environment == "dev" ? 0.9 : 0.8
}
