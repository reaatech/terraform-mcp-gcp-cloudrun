output "topic_ids" {
  description = "Map of topic name to fully-qualified topic ID (projects/<project>/topics/<name>)"
  value       = { for k, v in google_pubsub_topic.this : k => v.id }
}

output "topic_names" {
  description = "Map of topic name to fully-qualified topic ID (alias of topic_ids, kept for convenience)"
  value       = { for k, v in google_pubsub_topic.this : k => v.id }
}

output "subscription_ids" {
  description = "Map of subscription name to fully-qualified subscription ID"
  value       = { for k, v in google_pubsub_subscription.this : k => v.id }
}

output "subscription_names" {
  description = "Map of subscription name to fully-qualified subscription ID (alias of subscription_ids)"
  value       = { for k, v in google_pubsub_subscription.this : k => v.id }
}

output "dlq_topic_ids" {
  description = "Map of dead-letter topic name to fully-qualified topic ID"
  value       = { for k, v in google_pubsub_topic.dlq : k => v.id }
}
