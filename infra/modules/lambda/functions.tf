# Placeholder — real Lambda functions are detailed and complex.
# Recommend splitting further by lambda_ingest.tf, lambda_stream.tf, etc.
resource "aws_lambda_function" "placeholder" {
  function_name = "example"
  role          = "arn:aws:iam::123456789012:role/lambda_exec_role"
  runtime       = "python3.9"
  handler       = "handler.lambda_handler"
  filename      = "lambda.zip"
}
