output "account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "AWS account id, where you deployed infrastructure."
}

output "Lambda_function" {
  value       = aws_lambda_function.test_lambda.arn
  description = "Lambda function's ARN."
}