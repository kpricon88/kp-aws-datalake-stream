provider "aws" {
  region = var.aws_region
}

resource "aws_dynamodb_table" "items" {
  name         = "kp-dynamo-landing-tbl"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  range_key    = "srt_ky"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "srt_ky"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}

resource "aws_s3_bucket" "landing_zone" {
  bucket        = "dynamodb-landing-zone-example"
  force_destroy = true
}

resource "aws_s3_bucket" "cleansed_zone" {
  bucket        = "dynamodb-cleansed-zone-example"
  force_destroy = true
}

resource "aws_s3_bucket" "golden_zone" {
  bucket        = "s3-golden-bucket-kp-dev"
  force_destroy = true
  region        = "us-east-1"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_sqs_queue" "lambda_dlq" {
  name = "lambda-dlq-queue"
  visibility_timeout_seconds = 70 
}


resource "aws_lambda_function" "dynamo_stream_handler" {
  filename      = "${path.module}/../lambda/dynamo_stream_to_s3.py.zip"
  function_name = "DynamoStreamToS3"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "dynamo_stream_to_s3.lambda_handler"
  runtime       = "python3.9"
  timeout       = 5

  environment {
    variables = {
      DEST_BUCKET = aws_s3_bucket.landing_zone.bucket
      LOG_LEVEL   = "INFO"
    }
  }
  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  source_code_hash = filebase64sha256("${path.module}/../lambda/dynamo_stream_to_s3.py.zip")
}

resource "aws_lambda_function" "landing_to_cleansed" {
  function_name    = "LandingToCleansed"
  handler          = "landing_to_cleansed.lambda_handler"
  runtime          = "python3.9"
  filename         = "./../lambda/landing_to_cleansed.py.zip"
  source_code_hash = filebase64sha256("./../lambda/landing_to_cleansed.py.zip")
  role             = aws_iam_role.lambda_exec_role.arn
  timeout          = 3
  environment {
    variables = {
      CLEANSED_BUCKET = aws_s3_bucket.cleansed_zone.bucket
      LOG_LEVEL       = "INFO"
    }
  }
  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }
}

resource "aws_lambda_function" "cleansed_to_golden" {
  function_name    = "CleansedToGolden"
  handler          = "cleansed_to_golden.lambda_handler"
  runtime          = "python3.9"
  filename         = "./../lambda/cleansed_to_golden.py.zip"
  source_code_hash = filebase64sha256("./../lambda/cleansed_to_golden.py.zip")
  role             = aws_iam_role.lambda_exec_role.arn
  timeout          = 3
  environment {
    variables = {
      GOLDEN_BUCKET = aws_s3_bucket.golden_zone.bucket
      LOG_LEVEL     = "INFO"
    }
  }
  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.items.name
}

#resource "aws_lambda_permission" "allow_s3_landing" {
#  statement_id  = "AllowExecutionFromS3Landing"
#  action        = "lambda:InvokeFunction"
#  function_name = aws_lambda_function.landing_to_cleansed.function_name
#  principal     = "s3.amazonaws.com"
#  source_arn    = aws_s3_bucket.landing_zone.arn
#}

#resource "aws_lambda_permission" "allow_s3_cleansed" {
#  statement_id  = "AllowExecutionFromS3Cleansed"
#  action        = "lambda:InvokeFunction"
#  function_name = aws_lambda_function.cleansed_to_golden.function_name
#  principal     = "s3.amazonaws.com"
#  source_arn    = aws_s3_bucket.cleansed_zone.arn
#}

resource "aws_s3_bucket_notification" "landing_trigger" {
  bucket = aws_s3_bucket.landing_zone.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.landing_to_cleansed.arn
    events              = ["s3:ObjectCreated:*"]
  }

  #depends_on = [aws_lambda_permission.allow_s3_landing]
}

resource "aws_s3_bucket_notification" "cleansed_trigger" {
  bucket = aws_s3_bucket.cleansed_zone.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.cleansed_to_golden.arn
    events              = ["s3:ObjectCreated:*"]
  }

  #depends_on = [aws_lambda_permission.allow_s3_cleansed]
}

resource "aws_lambda_function" "dynamo_ingest_lambda" {
  function_name    = "ScheduledDynamoIngest"
  handler          = "dynamo_ingest_lambda.lambda_handler"
  runtime          = "python3.9"
  filename         = "${path.module}/../lambda/dynamo_ingest_lambda.py.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda/dynamo_ingest_lambda.py.zip")
  role             = aws_iam_role.lambda_exec_role.arn
  timeout          = 5
  environment {
    variables = {
      DYNAMO_TABLE = aws_dynamodb_table.items.name
    }
  }
}

resource "aws_cloudwatch_event_rule" "ingest_schedule" {
  name                = "dynamo-ingest-schedule"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "invoke_ingest_lambda" {
  rule      = aws_cloudwatch_event_rule.ingest_schedule.name
  target_id = "dynamoIngestLambda"
  arn       = aws_lambda_function.dynamo_ingest_lambda.arn
}

#resource "aws_lambda_permission" "allow_eventbridge_ingest" {
#  statement_id  = "AllowExecutionFromEventBridge"
#  action        = "lambda:InvokeFunction"
#  function_name = aws_lambda_function.dynamo_ingest_lambda.function_name
#  principal     = "events.amazonaws.com"
#  source_arn    = aws_cloudwatch_event_rule.ingest_schedule.arn
#}

resource "aws_lambda_event_source_mapping" "dynamo_to_landing" {
  event_source_arn  = aws_dynamodb_table.items.stream_arn
  function_name     = aws_lambda_function.dynamo_stream_handler.arn
  starting_position = "LATEST"

  depends_on = [aws_lambda_function.dynamo_stream_handler]
}

resource "aws_iam_policy" "dynamo_stream_policy" {
  name        = "dynamo_stream_policy"
  description = "Allow Lambda to read DynamoDB stream"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ],
        Resource = aws_dynamodb_table.items.stream_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dynamo_stream_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.dynamo_stream_policy.arn
}

resource "aws_iam_policy" "dynamo_putitem_policy" {
  name        = "AllowDynamoPutItem"
  description = "Allow Lambda to PutItem into DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem"
        ],
        Resource = aws_dynamodb_table.items.arn
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "attach_putitem_to_lambda" {
  name       = "attach-putitem-to-lambda"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = aws_iam_policy.dynamo_putitem_policy.arn
}

resource "aws_iam_policy" "lambda_put_s3" {
  name        = "LambdaS3PutAccess"
  description = "Allow Lambda to PutObject in S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject"
        ],
        Resource = "arn:aws:s3:::dynamodb-landing-zone-example/*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_put_s3_attach" {
  name       = "lambda-put-s3-attach"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = aws_iam_policy.lambda_put_s3.arn
}

resource "aws_iam_policy" "lambda_get_s3" {
  name        = "LambdaS3GetAccess"
  description = "Allow Lambda to GetObject from S3"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject"
        ],
        Resource = "arn:aws:s3:::dynamodb-landing-zone-example/*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_get_s3_attach" {
  name       = "lambda-get-s3-attach"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = aws_iam_policy.lambda_get_s3.arn
}



# ------------------------------
# CloudWatch Dashboard
# ------------------------------
resource "aws_cloudwatch_dashboard" "etl_pipeline_dashboard" {
  dashboard_name = "etl-monitoring-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        "type" : "metric",
        "x" : 0,
        "y" : 0,
        "width" : 12,
        "height" : 6,
        "properties" : {
          "metrics" : [
            ["AWS/Lambda", "Errors", "FunctionName", "DynamoStreamToS3"],
            [".", "Errors", "FunctionName", "LandingToCleansed"],
            [".", "Errors", "FunctionName", "CleansedToGolden"],
            [".", "Errors", "FunctionName", "ScheduledDynamoIngest"]
          ],
          "view" : "timeSeries",
          "stacked" : false,
          "region" : "us-east-1",
          "title" : "Lambda Errors"
        }
      },
      {
        "type" : "metric",
        "x" : 0,
        "y" : 6,
        "width" : 12,
        "height" : 6,
        "properties" : {
          "metrics" : [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.lambda_dlq.name]
          ],
          "view" : "singleValue",
          "region" : "us-east-1",
          "title" : "DLQ Messages"
        }
      }
    ]
  })
}



resource "aws_cloudwatch_metric_alarm" "lambda_dynamo_stream_errors" {
  alarm_name          = "dynamo_stream_to_s3-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Triggered when errors > 0 in dynamo_stream_to_s3"
  dimensions = {
    FunctionName = "dynamo_stream_to_s3"
  }
}

resource "aws_lambda_function" "dlq_reprocessor" {
  function_name = "lambda_dlq_reprocessor"
  filename      = "${path.module}/../lambda/dlq_reprocessor.py.zip"
  handler       = "dlq_reprocessor.lambda_handler"
  runtime       = "python3.9"
  timeout       = 60
  memory_size   = 256
  role          = aws_iam_role.lambda_exec_role.arn

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }
}

resource "aws_lambda_event_source_mapping" "dlq_reprocessor_trigger" {
  event_source_arn = aws_sqs_queue.lambda_dlq.arn
  function_name    = aws_lambda_function.dlq_reprocessor.arn
  enabled          = true
  batch_size       = 5
}

resource "aws_iam_policy" "lambda_dlq_sqs_send" {
  name        = "LambdaDLQSendPolicy"
  description = "Allow Lambda to send to DLQ SQS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage"
        ],
        Resource = aws_sqs_queue.lambda_dlq.arn
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_dlq_send_attach" {
  name       = "lambda-dlq-send-attach"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = aws_iam_policy.lambda_dlq_sqs_send.arn
}

resource "aws_iam_policy" "lambda_dlq_consume" {
  name        = "LambdaDLQConsumePolicy"
  description = "Allow Lambda to read from DLQ SQS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = aws_sqs_queue.lambda_dlq.arn
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_dlq_consume_attach" {
  name       = "lambda-dlq-consume-attach"
  roles      = [aws_iam_role.lambda_exec_role.name]
  policy_arn = aws_iam_policy.lambda_dlq_consume.arn
}


resource "aws_dynamodb_table" "items_audit" {
  name         = "kp_dynamo_audit_tbl"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  tags = {
    Environment = "prod"
    Purpose     = "audit-log"
  }
}