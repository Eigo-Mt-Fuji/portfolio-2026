data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "get_user_lambda" {
  name               = "${var.project_name}-${var.environment}-get-user-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = local.common_tags
}

# Attach the AWS-managed basic execution policy so the Lambda can write CloudWatch Logs.
resource "aws_iam_role_policy_attachment" "get_user_lambda_basic_execution" {
  role       = aws_iam_role.get_user_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
