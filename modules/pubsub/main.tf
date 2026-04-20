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
  # Collect every DLQ topic name referenced by subscriptions or the module-level default
  dlq_topic_names = distinct(compact(concat(
    var.dead_letter_topic != null ? [var.dead_letter_topic] : [],
    [for _, sub in var.subscriptions : sub.dead_letter_topic]
  )))

  # DLQ topics that aren't already in var.topics — we'll create these separately with DLQ labels
  extra_dlq_topics = [for t in local.dlq_topic_names : t if !contains(var.topics, t)]

  # Unified name -> topic id lookup for subscriptions and dead_letter_policy
  topic_ids = merge(
    { for k, v in google_pubsub_topic.this : k => v.id },
    { for k, v in google_pubsub_topic.dlq : k => v.id }
  )
}

# Regular Pub/Sub topics
resource "google_pubsub_topic" "this" {
  for_each = toset(var.topics)

  name    = each.value
  project = var.project_id

  labels = {
    "managed-by" = "terraform"
    "module"     = "pubsub"
  }
}

# Dead-letter topics (only those not already in var.topics)
resource "google_pubsub_topic" "dlq" {
  for_each = toset(local.extra_dlq_topics)

  name    = each.value
  project = var.project_id

  labels = {
    "managed-by" = "terraform"
    "module"     = "pubsub"
    "type"       = "dead-letter"
  }
}

resource "google_pubsub_subscription" "this" {
  for_each = var.subscriptions

  name    = each.key
  topic   = local.topic_ids[each.value.topic]
  project = var.project_id

  ack_deadline_seconds       = each.value.ack_deadline_seconds
  message_retention_duration = "${each.value.message_retention_seconds}s"

  dynamic "push_config" {
    for_each = each.value.push_endpoint != null ? [each.value] : []
    content {
      push_endpoint = push_config.value.push_endpoint

      dynamic "oidc_token" {
        for_each = push_config.value.push_service_account != null ? [push_config.value] : []
        content {
          service_account_email = oidc_token.value.push_service_account
        }
      }
    }
  }

  dynamic "dead_letter_policy" {
    for_each = (each.value.dead_letter_topic != null || var.dead_letter_topic != null) ? [1] : []
    content {
      dead_letter_topic     = local.topic_ids[coalesce(each.value.dead_letter_topic, var.dead_letter_topic)]
      max_delivery_attempts = each.value.max_delivery_attempts
    }
  }

  labels = {
    "managed-by" = "terraform"
    "module"     = "pubsub"
  }

  lifecycle {
    precondition {
      condition     = contains(keys(local.topic_ids), each.value.topic)
      error_message = "Subscription '${each.key}' references topic '${each.value.topic}' which is not defined in var.topics or as a dead_letter_topic."
    }
  }
}
