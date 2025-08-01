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
