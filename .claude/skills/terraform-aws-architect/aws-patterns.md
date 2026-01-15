# AWS Terraform Patterns & Standards

## Directory Structure

We enforce a strict separation between reusable modules (`infra/modules`) and environment-specific implementations (`infra/envs`).

```
infra/
├── envs/                      # Environment implementations (Consumers)
│   ├── dev/
│   │   ├── network/           # Component: Network
│   │   │   ├── main.tf        # Calls module-network
│   │   │   ├── backend.tf     # S3 backend config (Required)
│   │   │   ├── providers.tf   # Versions & Providers
│   │   │   ├── variables.tf   # Environment specific inputs
│   │   │   └── outputs.tf     # Component outputs
│   │   └── app-cluster/       # Component: App Cluster
│   │       └── ...
│   ├── stg/
│   └── prod/
│
└── modules/                   # Reusable logic (Producers)
    ├── network/               # Module: Network
    │   ├── main.tf            # Resource definitions
    │   ├── variables.tf       # Inputs (Interface)
    │   ├── outputs.tf         # Outputs (Interface)
    │   └── providers.tf       # Provider requirements (versions)
    └── app-cluster/
        └── ...
```

## Mandatory File Structure

Every component and module MUST contain the following files:

| File | Purpose | Requirement |
|------|---------|-------------|
| `main.tf` | Primary logic / Module instantiation | **Mandatory** |
| `variables.tf` | Input definitions with types & descriptions | **Mandatory** |
| `outputs.tf` | Output definitions (interface for other components) | **Mandatory** |
| `providers.tf` | Terraform/Provider version constraints | **Mandatory** |
| `backend.tf` | State management configuration | **Mandatory for Envs** |

---

## State Management Standard

**Strict Rule**: All environment components MUST use S3 Backend with DynamoDB locking.

### `backend.tf` Template
```hcl
terraform {
  backend "s3" {
    bucket         = "my-tfstate-bucket"
    key            = "envs/${var.env}/${var.component}/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "my-tfstate-lock"
    encrypt        = true
  }
}
```

---

## Lifecycle Management Patterns (Day 2 Ops)

Designs must consider future updates and maintenance.

### 1. Database Upgrades (RDS/Aurora)
- **Auto Minor Version Upgrade**: Explicitly set.
    - Dev: `true` (Test new versions automatically)
    - Prod: `false` (Control update timing)
- **Maintenance Window**: Must be defined explicitly.
    - Example: `backup_window = "03:00-04:00"`, `maintenance_window = "mon:04:00-mon:05:00"`

### 2. Resource Naming (Immutability)
- Avoid reusing names when resource replacement is required.
- Use `name_prefix` where possible to allow zero-downtime replacement (create before destroy).

### 3. Protection
- **Deletion Protection**: Enable for stateful resources (RDS, S3, ALB logs) in Production.
- **Lifecycle Block**: Use `lifecycle { prevent_destroy = true }` for critical data stores.

---

## Non-Functional Requirements (NFR) Checklist

Design must address these 6 pillars:

1.  **Operational Excellence**: Tagging strategies, CloudWatch logs.
2.  **Security**: Private subnets by default, minimal Security Group rules, Encryption at rest (KMS).
3.  **Reliability**: Multi-AZ for Prod, Auto-scaling.
4.  **Performance Efficiency**: Right-sizing instances (e.g., t3 for dev, m5 for prod).
5.  **Cost Optimization**: Spot instances for stateless workloads, GP3 over GP2.
6.  **Sustainability**: Use Graviton (ARM) instances where possible.

---

## Naming Conventions

- **Directories**: `kebab-case` (e.g., `vpc-network`)
- **Resources**: `snake_case` (e.g., `aws_s3_bucket.log_bucket`)
- **Variables**: `snake_case` (e.g., `instance_type`)
- **Outputs**: `snake_case` (e.g., `db_endpoint`)

### Resource Name Format
`{project}-{env}-{component}-{resource}`
Example: `portfolio-prod-api-app_server`
