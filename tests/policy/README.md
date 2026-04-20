# Policy Tests

This directory is reserved for [OPA](https://www.openpolicyagent.org/) / [Conftest](https://www.conftest.dev/) policies that validate `terraform plan` output against organizational rules.

Policies are not wired into CI by default — Checkov (see `.github/workflows/ci.yml`) provides an out-of-the-box security baseline, and custom policies vary heavily by organization. Drop your `.rego` files here and run:

```bash
cd environments/dev
terraform plan -out=plan.bin
terraform show -json plan.bin > plan.json
conftest test plan.json --policy ../../tests/policy
```

## Suggested starting policies

- Deny `google_cloud_run_v2_service` with `ingress = "INGRESS_TRAFFIC_ALL"` in non-dev environments.
- Require `google_firestore_database.delete_protection_state == "DELETE_PROTECTION_ENABLED"` in production.
- Deny `google_project_iam_member` with `roles/owner` or `roles/editor`.
- Deny `google_secret_manager_secret_iam_member.member == "allUsers"` or `"allAuthenticatedUsers"`.
- Require every `google_pubsub_subscription` to set `dead_letter_policy`.

Rego files in this directory should operate on the `resource_changes[]` array of a JSON plan.
