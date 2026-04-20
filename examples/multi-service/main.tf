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
  common_labels = {
    environment = "example-multi"
    managed-by  = "terraform"
    example     = "multi-service"
  }

  orchestrator_sa_member = "serviceAccount:${module.iam.service_account_emails["orchestrator-sa"]}"
  agent_sa_member        = "serviceAccount:${module.iam.service_account_emails["agent-sa"]}"
}

module "iam" {
  source = "../../modules/iam"

  project_id = var.project_id

  service_accounts = {
    orchestrator-sa = {
      account_id   = "mcp-orchestrator-sa"
      display_name = "Service account for MCP Orchestrator"
      description  = "Service account for MCP orchestrator in multi-service example"
    }
    agent-sa = {
      account_id   = "mcp-agent-sa"
      display_name = "Service account for MCP Agents"
      description  = "Service account for MCP agents in multi-service example"
    }
  }

  bindings = []
}

resource "google_project_iam_member" "firestore_access_orchestrator" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = local.orchestrator_sa_member
}

resource "google_project_iam_member" "trace_access_orchestrator" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = local.orchestrator_sa_member
}

resource "google_project_iam_member" "firestore_access_agents" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = local.agent_sa_member
}

resource "google_project_iam_member" "trace_access_agents" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = local.agent_sa_member
}

module "firestore" {
  source = "../../modules/firestore"

  project_id             = var.project_id
  database_id            = var.firestore_database_id
  location               = var.firestore_location
  delete_protection      = false
  point_in_time_recovery = false
}

module "pubsub" {
  source = "../../modules/pubsub"

  project_id = var.project_id
  topics     = ["orchestrator-tasks", "agent-results"]

  subscriptions = {
    orchestrator-tasks-sub = {
      topic                     = "orchestrator-tasks"
      push_endpoint             = module.orchestrator.service_url
      push_service_account      = module.iam.service_account_emails["orchestrator-sa"]
      ack_deadline_seconds      = 60
      message_retention_seconds = 604800
      max_delivery_attempts     = 5
      dead_letter_topic         = "mcp-dlq"
    }
    agent-results-sub = {
      topic                     = "agent-results"
      push_endpoint             = length(module.agents) > 0 ? values(module.agents)[0].service_url : null
      push_service_account      = module.iam.service_account_emails["agent-sa"]
      ack_deadline_seconds      = 30
      message_retention_seconds = 604800
      max_delivery_attempts     = 5
      dead_letter_topic         = "mcp-dlq"
    }
  }

  dead_letter_topic = "mcp-dlq"
}

module "orchestrator" {
  source = "../../modules/cloud-run"

  name                  = "orchestrator"
  region                = var.region
  project_id            = var.project_id
  image                 = var.orchestrator_image
  service_account_email = module.iam.service_account_emails["orchestrator-sa"]

  min_instances = 0
  max_instances = 2

  cpu             = "500m"
  memory          = "512Mi"
  timeout_seconds = 120
  concurrency     = 80

  ingress               = "all"
  allow_unauthenticated = true

  env_vars = {
    ENVIRONMENT    = "example-multi"
    LOG_LEVEL      = "DEBUG"
    FIRESTORE_DB   = module.firestore.database_id
    PUBSUB_TASKS   = "orchestrator-tasks"
    PUBSUB_RESULTS = "agent-results"
  }

  labels = merge(local.common_labels, { component = "orchestrator" })

  invoker_members = []
}

module "agents" {
  source = "../../modules/cloud-run"

  for_each = { for agent in var.agents : agent.name => agent }

  name                  = each.value.name
  region                = var.region
  project_id            = var.project_id
  image                 = each.value.image
  service_account_email = module.iam.service_account_emails["agent-sa"]

  min_instances = 0
  max_instances = 5

  cpu             = "250m"
  memory          = "256Mi"
  timeout_seconds = 60
  concurrency     = 80

  ingress               = "all"
  allow_unauthenticated = true

  env_vars = {
    ENVIRONMENT    = "example-multi"
    LOG_LEVEL      = "DEBUG"
    FIRESTORE_DB   = module.firestore.database_id
    PUBSUB_TASKS   = "orchestrator-tasks"
    PUBSUB_RESULTS = "agent-results"
    AGENT_NAME     = each.value.name
  }

  labels = merge(local.common_labels, { component = "agent" })

  invoker_members = []
}

# Per-service monitoring: orchestrator + each agent
module "monitoring_orchestrator" {
  source = "../../modules/monitoring"

  project_id       = var.project_id
  service_name     = module.orchestrator.service_name
  service_location = var.region
  alert_email      = var.alert_email

  latency_threshold_ms      = 5000
  error_rate_rps            = 5
  cpu_utilization_threshold = 0.9
}

module "monitoring_agents" {
  source = "../../modules/monitoring"

  for_each = module.agents

  project_id       = var.project_id
  service_name     = each.value.service_name
  service_location = var.region
  alert_email      = var.alert_email

  latency_threshold_ms      = 5000
  error_rate_rps            = 5
  cpu_utilization_threshold = 0.9
}
