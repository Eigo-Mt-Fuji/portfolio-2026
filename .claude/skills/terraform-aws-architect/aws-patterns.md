# AWS Terraform Patterns & Standards

## Directory Structure

We enforce a strict separation between reusable modules (`infra/modules`) and environment-specific implementations (`infra/envs`).

```
infra/
├── envs/                      # Environment implementations (Consumers)
│   ├── dev/
│   │   ├── network/           # Component: Network
│   │   │   ├── main.tf        # Calls module-network
│   │   │   ├── backend.tf
│   │   │   └── variables.tf
│   │   └── app-cluster/       # Component: App Cluster
│   │       └── ...
│   ├── stg/
│   └── prod/
│
└── modules/                   # Reusable logic (Producers)
    ├── network/               # Module: Network
    │   ├── main.tf            # Resource definitions
    │   ├── variables.tf       # Inputs
    │   └── outputs.tf         # Outputs
    └── app-cluster/
        └── ...
```

## Design Philosophy: "Component-First, Module-Driven"

1.  **Start with the Goal**: Define what infrastructure component you need (e.g., "I need an ECS cluster").
2.  **Modularize by Default**: Even if used once, wrap logic in a module in `infra/modules/`.
3.  **Instantiate in Envs**: The code in `infra/envs/` should primarily consist of `module` blocks and necessary `provider`/`terraform` configurations.

---

## Naming Conventions

- **Directories**: `kebab-case` (e.g., `vpc-network`, `app-server`)
- **Resources**: `snake_case` (e.g., `aws_s3_bucket.log_bucket`)
- **Variables**: `snake_case` (e.g., `instance_type`, `environment`)
- **Outputs**: `snake_case` (e.g., `bucket_arn`, `vpc_id`)

---

## Template: Module (`infra/modules/xxx/`)

### `main.tf`
```hcl
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

# ... other resources
```

### `variables.tf`
```hcl
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

### `outputs.tf`
```hcl
output "bucket_arn" {
  description = "ARN of the created bucket"
  value       = aws_s3_bucket.this.arn
}
```

---

## Template: Component (`infra/envs/{env}/xxx/`)

### `main.tf`
```hcl
module "s3_bucket" {
  source = "../../../modules/s3-bucket"  # Relative path to module

  bucket_name = "my-app-${var.environment}-assets"
  tags        = local.tags
}
```

### `backend.tf` (Example for S3 backend)
```hcl
terraform {
  backend "s3" {
    bucket = "my-tfstate-bucket"
    key    = "envs/dev/assets/terraform.tfstate"
    region = "ap-northeast-1"
  }
}
```
