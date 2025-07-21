

output "landing_zone_bucket" {
  description = "S3 bucket for landing raw data from DynamoDB stream"
  value       = aws_s3_bucket.landing_zone.bucket
}

output "cleansed_zone_bucket" {
  description = "S3 bucket for cleansed/processed data"
  value       = aws_s3_bucket.cleansed_zone.bucket
}

output "golden_zone_bucket" {
  description = "S3 bucket for golden/curated data"
  value       = aws_s3_bucket.golden_zone.bucket
}

output "lambda_stream_function_name" {
  description = "Lambda function triggered by DynamoDB Stream"
  value       = aws_lambda_function.dynamo_stream_handler.function_name
}

output "lambda_execution_role" {
  description = "IAM role used by Lambda function"
  value       = aws_iam_role.lambda_exec_role.arn
}