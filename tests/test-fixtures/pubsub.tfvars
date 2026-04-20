project_id = "test-project"

topics = ["test-topic-1", "test-topic-2"]

subscriptions = {
  test-sub = {
    topic                     = "test-topic-1"
    push_endpoint             = "https://example.com/push"
    push_service_account      = "test-sa@test-project.iam.gserviceaccount.com"
    ack_deadline_seconds      = 30
    message_retention_seconds = 604800
    max_delivery_attempts     = 5
    dead_letter_topic         = "test-dlq"
  }
}

dead_letter_topic = "test-dlq"
