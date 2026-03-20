terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  function_name    = "${var.project_name}-${var.environment}-get-user"
  lambda_src_dir   = "${path.module}/../lambda/get-user"
  lambda_build_dir = "${path.module}/../lambda/get-user/build"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Build artifact
# The binary must be pre-built before terraform apply.
# Build command: GOARCH=amd64 GOOS=linux go build -o lambda/get-user/build/bootstrap ./lambda/get-user/
# ---------------------------------------------------------------------------

data "archive_file" "get_user" {
  type        = "zip"
  source_file = "${local.lambda_build_dir}/bootstrap"
  output_path = "${local.lambda_build_dir}/get-user.zip"
}

# ---------------------------------------------------------------------------
# Lambda function
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "get_user" {
  function_name    = local.function_name
  role             = aws_iam_role.get_user_lambda.arn
  filename         = data.archive_file.get_user.output_path
  source_code_hash = data.archive_file.get_user.output_base64sha256
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  architectures    = ["x86_64"]
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = local.common_tags
}

# CloudWatch Log Group with retention
resource "aws_cloudwatch_log_group" "get_user" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 7

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# API Gateway (HTTP API v2)
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET"]
    allow_headers = ["Content-Type"]
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "get_user" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_user.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_user" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /users/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.get_user.id}"
}

# Allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_user.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
