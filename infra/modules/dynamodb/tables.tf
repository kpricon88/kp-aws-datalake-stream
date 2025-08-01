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
