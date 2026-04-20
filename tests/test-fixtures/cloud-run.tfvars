name                  = "test-cloud-run"
region                = "us-central1"
project_id            = "test-project"
image                 = "gcr.io/test-project/test-image:latest"
service_account_email = "test-sa@test-project.iam.gserviceaccount.com"

min_instances = 0
max_instances = 2

cpu             = "250m"
memory          = "256Mi"
timeout_seconds = 60
concurrency     = 80

ingress               = "internal-and-cloud-load-balancing"
allow_unauthenticated = true

env_vars = {
  ENVIRONMENT = "test"
  LOG_LEVEL   = "DEBUG"
}
