
resource "aws_lambda_function" "dynamo_ingest" {
  function_name = "ScheduledDynamoIngest"
  handler       = "handler.lambda_handler"
  runtime       = "python3.9"
  filename      = "${path.module}/../../../packages/dynamo_ingest.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../packages/dynamo_ingest.zip")
  role          = "arn:aws:iam::123456789012:role/lambda_exec_role"
  timeout       = 5

  environment {
    variables = {
      DYNAMO_TABLE = "kp-dynamo-landing-tbl"
    }
  }
}

resource "aws_lambda_function" "dynamo_stream_handler" {
  function_name = "DynamoStreamToS3"
  handler       = "handler.lambda_handler"
  runtime       = "python3.9"
  filename      = "${path.module}/../../../packages/dynamo_stream.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../packages/dynamo_stream.zip")
  role          = "arn:aws:iam::123456789012:role/lambda_exec_role"
  timeout       = 5

  environment {
    variables = {
      DEST_BUCKET = "dynamodb-landing-zone-example"
    }
  }
}

resource "aws_lambda_function" "landing_to_cleansed" {
  function_name = "LandingToCleansed"
  handler       = "handler.lambda_handler"
  runtime       = "python3.9"
  filename      = "${path.module}/../../../packages/landing_to_cleansed.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../packages/landing_to_cleansed.zip")
  role          = "arn:aws:iam::123456789012:role/lambda_exec_role"
  timeout       = 3

  environment {
    variables = {
      CLEANSED_BUCKET = "dynamodb-cleansed-zone-example"
    }
  }
}

resource "aws_lambda_function" "cleansed_to_golden" {
  function_name = "CleansedToGolden"
  handler       = "handler.lambda_handler"
  runtime       = "python3.9"
  filename      = "${path.module}/../../../packages/cleansed_to_golden.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../packages/cleansed_to_golden.zip")
  role          = "arn:aws:iam::123456789012:role/lambda_exec_role"
  timeout       = 3

  environment {
    variables = {
      GOLDEN_BUCKET = "s3-golden-bucket-kp-dev"
    }
  }
}

resource "aws_lambda_function" "dlq_reprocessor" {
  function_name = "lambda_dlq_reprocessor"
  handler       = "handler.lambda_handler"
  runtime       = "python3.9"
  filename      = "${path.module}/../../../packages/dlq_reprocessor.zip"
  source_code_hash = filebase64sha256("${path.module}/../../../packages/dlq_reprocessor.zip")
  role          = "arn:aws:iam::123456789012:role/lambda_exec_role"
  timeout       = 60
  memory_size   = 256

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }
}
