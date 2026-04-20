# terraform-mcp-gcp-cloudrun

Drop-in Terraform module to deploy any MCP server on Google Cloud Run with Firestore for session state, Secret Manager for credentials, and Pub/Sub for async task distribution.

## What This Is

A production-ready infrastructure template for deploying MCP (Model Context Protocol) servers to GCP with best practices built in:

- **Auto-scaling** — Scale to zero for dev, scale up for production
- **Observability** — Cloud Monitoring dashboards and alert policies
- **Security** — Least privilege IAM, Secret Manager integration, private ingress
- **Persistence** — Firestore for session state with TTL cleanup
- **Async** — Pub/Sub for task distribution with dead-letter queues

## Quick Start (5 Minutes)

### Prerequisites

- Terraform >= 1.6
- `gcloud` CLI authenticated (`gcloud auth application-default login`)
- A GCP project with billing enabled

### Deploy

```bash
# 1. Navigate to dev environment
cd environments/dev

# 2. Configure your deployment
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project ID and MCP server image

# 3. Deploy
terraform init
terraform plan
terraform apply

# 4. Get the service URL
export SERVICE_URL=$(terraform output -raw cloud_run_services | jq -r '.[].url' | head -1)

# Test the health endpoint
curl $SERVICE_URL/health
```

## Module Reference

### Cloud Run Module

```hcl
module "cloud_run" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/cloud-run"

  name                  = "my-mcp-server"
  region                = "us-central1"
  project_id            = "my-project"
  image                 = "gcr.io/my-project/my-mcp-server:latest"
  service_account_email = module.iam.service_accounts["mcp-sa"].email

  min_instances = 0  # Scale to zero for dev
  max_instances = 10

  allow_unauthenticated = true  # For testing only!
}
```

### Firestore Module

```hcl
module "firestore" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/firestore"

  project_id          = "my-project"
  database_id         = "(default)"
  location            = "us-central"
  delete_protection   = true
  point_in_time_recovery = true
}
```

### Secret Manager Module

```hcl
module "secrets" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/secrets"

  project_id = "my-project"
  secrets = {
    api-key = {
      secret_id = "mcp-api-key"
    }
  }
  accessors = [module.iam.service_accounts["mcp-sa"].email]
}
```

### Pub/Sub Module

```hcl
module "pubsub" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/pubsub"

  project_id = "my-project"
  topics     = ["mcp-tasks", "mcp-results"]

  subscriptions = {
    mcp-tasks-sub = {
      topic                   = "mcp-tasks"
      push_endpoint          = module.cloud_run.service_url
      push_service_account   = module.iam.service_accounts["pubsub-sa"].email
    }
  }
}
```

## Examples


| Example                                              | Description                     | Use Case                           |
| ---------------------------------------------------- | ------------------------------- | ---------------------------------- |
| [`examples/basic/`](examples/basic/)                 | Single service with Firestore   | Quick testing and development      |
| [`examples/multi-service/`](examples/multi-service/) | Multiple services with Pub/Sub  | Orchestrator + agent architectures |
| [`examples/vpc-sc/`](examples/vpc-sc/)               | VPC Service Controls compatible | Production with network isolation  |

## Environments


| Environment                                | Description                                     |
| ------------------------------------------ | ----------------------------------------------- |
| [`environments/dev/`](environments/dev/)   | Development configuration with scale-to-zero    |
| [`environments/prod/`](environments/prod/) | Production configuration with high availability |

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   MCP Client    │────▶│   Cloud Run      │────▶│   Firestore    │
│   (agent-mesh)  │     │   Service        │     │  (Sessions)    │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │  Secret Manager  │
                       │  (API Keys)      │
                       └──────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │     Pub/Sub      │
                       │  (Async Tasks)   │
                       └──────────────────┘
```

## Security Model

- **Defense in depth** — Network isolation, IAM, secrets, data encryption
- **Least privilege** — One service account per MCP server with minimal permissions
- **No secrets in state** — All credentials from Secret Manager
- **Private by default** — Internal ingress, VPC connector support

## Cost Optimization


| Workload   | CPU   | Memory | Min/Max Instances | Est. Monthly |
| ---------- | ----- | ------ | ----------------- | ------------ |
| Dev        | 250m  | 256Mi  | 0/2               | ~$0-3        |
| Medium     | 500m  | 512Mi  | 0/5               | ~$10-15      |
| Production | 2000m | 2048Mi | 1/20              | ~$50-100     |

## Documentation

- **[AGENTS.md](AGENTS.md)** — Agent deployment guide with integration patterns
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — System design deep dive

## Contributing

1. Follow the development plan in `DEV_PLAN.md`
2. Run `terraform fmt -recursive` and `tflint` before committing
3. Add tests for new functionality
4. Update documentation as needed

## License

MIT License — see [LICENSE](LICENSE) for details.

## References

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google)
- [MCP Protocol Specification](https://spec.modelcontextprotocol.io/)
