resource "aws_glue_catalog_database" "data_lake" {
  name = "kp_datalake"
}

resource "aws_glue_crawler" "landing_zone" {
  name          = "crawler-landing"
  role          = "arn:aws:iam::123456789012:role/glue_service_role"
  database_name = aws_glue_catalog_database.data_lake.name
  table_prefix  = "landing_"
  s3_target {
    path = "s3://dynamodb-landing-zone-example/"
  }
  schedule = "cron(0/15 * * * ? *)"
}

resource "aws_glue_crawler" "cleansed_zone" {
  name          = "crawler-cleansed"
  role          = "arn:aws:iam::123456789012:role/glue_service_role"
  database_name = aws_glue_catalog_database.data_lake.name
  table_prefix  = "cleansed_"
  s3_target {
    path = "s3://dynamodb-cleansed-zone-example/"
  }
  schedule = "cron(5/15 * * * ? *)"
}

resource "aws_glue_crawler" "golden_zone" {
  name          = "crawler-golden"
  role          = "arn:aws:iam::123456789012:role/glue_service_role"
  database_name = aws_glue_catalog_database.data_lake.name
  table_prefix  = "golden_"
  s3_target {
    path = "s3://s3-golden-bucket-kp-dev/"
  }
  schedule = "cron(10/15 * * * ? *)"
}
