# Learnline

A serverless education-analytics lakehouse on AWS, built entirely with infrastructure as code.

> **Status:** in progress. The infrastructure foundation and storage layer are built. Ingestion, transformations, orchestration and monitoring are planned (see [Roadmap](#roadmap)).

## Architecture

**Built so far**

```
Terraform (remote state in S3, locked + versioned)
        │
        ├── S3 raw bucket          (bronze: data exactly as it arrives)
        ├── S3 clean bucket        (silver: validated, standardised data)
        ├── S3 Athena results      (query output, auto-deleted after 7 days)
        ├── Glue Data Catalog DB   (metastore: table definitions only)
        └── Athena workgroup       (serverless SQL, 100 MB per-query scan limit)
```

**Planned:** scheduled Lambda ingestion (UK DfE education statistics and synthetic practice data) → dbt models in Athena (Iceberg) → dashboard and CloudWatch alerting.

## AWS account setup

- **Separate account per purpose.** AWS Organizations keeps this project in its own member account, isolated from an unrelated production workload. A mistake here cannot affect anything outside this account.
- **No day-to-day root use.** The root user is protected with MFA. Everyday access is through **IAM Identity Center** with its own MFA.
- **Short-lived credentials.** The AWS CLI authenticates through SSO, so credentials are temporary and expire after a few hours. No long-lived access keys exist on disk.
- **Cost alerts.** A monthly budget scoped to this account sends email alerts.

## Infrastructure as code (Terraform)

All infrastructure is defined in Terraform. Nothing is created by clicking in the console.

- **Account guardrail:** the AWS provider sets `allowed_account_ids`, so Terraform refuses to run against any other account, even if the wrong credentials are active.
- **Remote state:** state lives in S3 (key `infra/terraform.tfstate`), encrypted at rest and **versioned**, so any earlier state can be restored after a bad change.
- **State locking:** `use_lockfile = true` writes a lock file in S3 during a run, so two applies cannot run at once and corrupt the state.
- **Bootstrap:** the state bucket is created by a separate, tiny `bootstrap/` config with local state. This solves the chicken-and-egg problem: the bucket must exist before Terraform can store state in it. It is protected with `prevent_destroy`.
- **Tagging:** `default_tags` on the provider labels every resource with `Project`, `ManagedBy = terraform` and `Repository`, for cost tracking and to spot anything created outside Terraform.
- **Variables and outputs:** project name, account ID and region are variables; bucket, database and workgroup names are exposed as outputs.
- **State never in git:** `.gitignore` excludes `.terraform/` and all `*.tfstate` files, because state can contain sensitive values.

## CI/CD (GitHub Actions + OIDC)

Infrastructure changes are deployed by GitHub Actions ([`.github/workflows/terraform.yml`](.github/workflows/terraform.yml)), not from a laptop.

- **Pull request:** `fmt -check`, `init`, `validate` and `plan` run on every PR that touches `infra/`, so the exact change is visible before anything is merged.
- **Merge to main:** the same workflow runs again and applies the saved plan. Apply runs only on `main`.
- **No stored AWS keys:** the workflow authenticates with **OIDC**. GitHub issues a short-lived signed token for each run, and AWS exchanges it for temporary credentials by assuming the `learnline-github-actions` role. There are no secrets to leak or rotate.
- **Locked-down trust policy:** the role trusts only tokens whose audience is `sts.amazonaws.com` and whose subject is this repository, matched by its **immutable owner and repository IDs**, not just its name. A renamed or deleted repo name re-registered by someone else cannot assume the role (repojacking).
- **One run at a time:** a `concurrency` group stops two workflow runs overlapping, on top of Terraform's state lock.
- **Bootstrap stays manual:** the OIDC provider and role live in `bootstrap/`, applied locally, so CI cannot change its own permissions.

Known trade-off: the CI role currently has `AdministratorAccess` in this isolated account. Scoping it down to least privilege is on the roadmap.

## Storage and query layer

- **Medallion zones in S3:** a raw (bronze) bucket keeps data exactly as received, so the pipeline can always be replayed; a clean (silver) bucket holds validated, standardised data. Gold marts will be built by dbt.
- **Private by default:** every bucket has an S3 public access block, so it cannot be made public by accident.
- **Glue Data Catalog** acts as Athena's metastore: it stores only table definitions, mapping S3 locations to tables and columns. It holds no data itself.
- **Athena** runs serverless SQL directly over S3, with no database server running.
- **Cost guardrail:** the Athena workgroup enforces a **100 MB per-query scan limit**. Athena charges per data scanned, so any query that would scan more is cancelled. The setting is enforced, so it cannot be overridden per query.
- **Housekeeping:** Athena writes a result file for every query, so the results bucket has a **7-day lifecycle rule** that deletes old results automatically.

## Running it

Prerequisites: AWS CLI v2, Terraform ≥ 1.10, and an SSO profile named `learnline`.

```bash
# Log in (credentials are short-lived)
aws sso login --sso-session <your-session>
aws sts get-caller-identity --profile learnline   # confirm the account before changing anything

# One-off: create the remote-state bucket
cd bootstrap && terraform init && terraform apply

# Main infrastructure
cd ../infra && terraform init && terraform plan && terraform apply
terraform output
```

## Design decisions

| Decision | Why |
| --- | --- |
| Separate AWS account | Hard isolation from other workloads; mistakes cannot leak across accounts |
| SSO instead of access keys | Short-lived credentials limit the damage if anything leaks |
| Remote state, versioned and locked | One source of truth, recoverable, safe from concurrent runs |
| Bootstrap with local state | Solves the chicken-and-egg problem of the state bucket |
| Serverless only (S3, Athena) | Pay per use; no always-on servers on a tight budget |
| Enforced Athena scan limit | A bad query cannot run up a bill |
| OIDC instead of CI access keys | No long-lived secrets; every run gets credentials that expire |
| Plan on PR, apply on merge | Every change to AWS is reviewed as a plan before it happens |

## Cost

Everything built so far is serverless and pay-per-use. At this project's data size, expected cost is a few pence per month. A budget alert guards against surprises.

## Roadmap

- [x] Week 0: account isolation, SSO, MFA, budget alerts
- [x] Week 1: Terraform, remote state, storage layer, Athena workgroup
- [x] Week 1: GitHub Actions deployment with OIDC (no stored keys)
- [ ] Scope the CI role down from AdministratorAccess to least privilege
- [ ] Week 2: Lambda ingestion from the UK DfE statistics API
- [ ] Week 3: synthetic practice-data generator
- [ ] Week 4: dbt models and tests in Athena (Iceberg)
- [ ] Week 5: scheduling and an Airflow DAG
- [ ] Week 6: monitoring and alerting
- [ ] Week 7: dashboard and documentation
- [ ] Week 8: teardown-and-rebuild test, demo