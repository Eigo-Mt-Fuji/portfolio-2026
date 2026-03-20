output "api_endpoint" {
  description = "Base URL of the HTTP API Gateway"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "get_user_endpoint" {
  description = "Full URL for GET /users/{id}"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/users/{id}"
}

output "lambda_function_name" {
  description = "Name of the deployed Lambda function"
  value       = aws_lambda_function.get_user.function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed Lambda function"
  value       = aws_lambda_function.get_user.arn
}

output "lambda_iam_role_arn" {
  description = "ARN of the IAM role attached to the Lambda function"
  value       = aws_iam_role.get_user_lambda.arn
}
