# Firestore Deployment

## Capability
Deploy Firestore Native databases for session state persistence with delete protection and point-in-time recovery.

## Terraform Resources
| Resource | Purpose | Key Configuration |
|----------|---------|-------------------|
| `google_firestore_database` | Firestore Native database | `delete_protection`, `point_in_time_recovery` |
| `google_firestore_index` | Composite indexes | Session queries by user_id, status, ttl |

## Usage Examples

### Basic Database
```hcl
module "firestore" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/firestore"

  project_id  = "my-project"
  location    = "us-central"
  database_id = "(default)"
}
```

### Production Database with Protection
```hcl
module "firestore" {
  source = "github.com/reaatech/terraform-mcp-gcp-cloudrun//modules/firestore"

  project_id              = "my-project"
  location               = "us-central1"
  database_id            = "mcp-sessions"
  delete_protection      = true
  point_in_time_recovery = true
}
```

## Error Handling
- **Database creation fails**: Ensure billing is enabled on the GCP project
- **PITR validation error**: PITR requires Firestore Native mode (not Datastore mode)
- **Location conflict**: Ensure region matches your Cloud Run service region

## Security Considerations
- Enable `delete_protection` in production to prevent accidental deletion
- Enable `point_in_time_recovery` for disaster recovery capability
- Use Firestore IAM to restrict database access
- Consider VPC Service Controls for sensitive workloads

## Outputs
| Output | Description |
|--------|-------------|
| `database_name` | Firestore database name |
| `location` | Database location |