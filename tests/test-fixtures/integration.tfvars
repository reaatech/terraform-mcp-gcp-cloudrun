project_id = "test-project"
region     = "us-central1"

mcp_servers = [
  {
    name  = "test-mcp-server"
    image = "gcr.io/test-project/test-image:latest"
  }
]

firestore_database_id = "(default)"
firestore_location    = "us-central"

environment   = "test"
alert_email   = "test@example.com"
enable_pubsub = false
pubsub_topics = []
