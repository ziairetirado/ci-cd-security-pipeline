# CI/CD Security Pipeline for Terraform

A GitHub Actions pipeline that scans Terraform code for security misconfigurations
before it's allowed to deploy. If a scan finds a high/critical issue, the pipeline
stops — the `plan` and `deploy` jobs never run.

## The problem

Terraform makes it easy to stand up infrastructure fast, but that speed cuts both
ways: a public S3 bucket, an SSH port open to `0.0.0.0/0`, or an unencrypted
resource can get merged and deployed just as fast as anything else if there's no
automated check in the way. Manual code review catches some of this, but it's
inconsistent and doesn't scale — reviewers miss things, and by the time a human
looks at it the infra may already be live.

## The approach

Treat security scanning as a required CI gate, not an optional linter. The pipeline
runs on every push/PR that touches `terraform/**` and enforces a strict order:

```
fmt/validate → tfsec scan → checkov scan → terraform plan → deploy
                  |              |
                  └── fail ──────┴──→ pipeline stops, nothing downstream runs
```

Two scanners instead of one, on purpose:
- **tfsec** — fast, Terraform-native static analysis, good at catching the
  common stuff (open security groups, public buckets, missing encryption).
- **Checkov** — broader policy-as-code engine with CIS benchmark coverage and
  secret-scanning, catches things tfsec's ruleset doesn't.

Both are configured with `soft_fail: false`, so a finding fails the job outright
instead of just posting a warning. The `plan` and `deploy` jobs declare
`needs: [validate, tfsec, checkov]`, so GitHub Actions won't even start them
unless every prior job succeeded — there's no code path that reaches `deploy`
with a failing scan.

## What the pipeline catches

`terraform/main.tf` in this repo is deliberately left with a few real-world
misconfigurations so the scanners have something to flag:

| Issue | Resource | Fix |
|---|---|---|
| Public-read ACL | `aws_s3_bucket_acl.demo` | Remove the ACL, add a `aws_s3_bucket_public_access_block` resource blocking all public access |
| No encryption at rest | `aws_s3_bucket.demo` | Add `aws_s3_bucket_server_side_encryption_configuration` with `AES256` or a KMS key |
| No versioning | `aws_s3_bucket.demo` | Add `aws_s3_bucket_versioning` with `status = "Enabled"` |
| SSH open to the internet | `aws_security_group.demo` | Restrict `cidr_blocks` to a known IP range or VPN CIDR, never `0.0.0.0/0` on port 22 |

Running the workflow against this code fails at the `tfsec` and `checkov` jobs,
which is the point — it proves the gate actually blocks bad config instead of
just running and passing everything.

## Repo layout

```
.github/workflows/security-pipeline.yml   # the pipeline itself
terraform/
  main.tf          # demo resources (intentionally insecure, see table above)
  variables.tf
  outputs.tf
  versions.tf
```

## Pipeline stages

1. **validate** — `terraform fmt -check` and `terraform validate`. Cheap checks
   that fail fast before burning time on a full scan.
2. **tfsec** — Terraform-specific static analysis via `aquasecurity/tfsec-action`.
3. **checkov** — policy-as-code scan via `bridgecrewio/checkov-action`, run in
   parallel with tfsec.
4. **plan** — only runs if `validate`, `tfsec`, and `checkov` all succeeded.
   Runs `terraform plan` as the last checkpoint before deploy.
5. **deploy** — gated behind `plan`, scoped to the `main` branch, and tied to a
   GitHub `environment` so manual approval can be layered on top in repo
   settings. In a real deployment this job would assume an AWS role via OIDC
   rather than long-lived credentials.

## Running it

1. Push this repo to GitHub.
2. Open a PR that touches anything under `terraform/`.
3. Watch the Actions tab — `tfsec` and `checkov` fail on the intentional
   misconfigurations above, and `plan`/`deploy` never start.
4. Apply the fixes from the table, push again — the scans pass and `plan` runs.

## What I'd add next

- Wire the `deploy` job to real AWS credentials via OIDC (no static keys in
  GitHub secrets).
- Add `.tfsec.yml` / Checkov baseline files to formally document any accepted
  exceptions instead of silently passing.
- Post scan results as a PR comment (both actions support this) so reviewers
  see findings without leaving GitHub.
- Add a `terraform-docs` step to auto-generate documentation on every PR.
