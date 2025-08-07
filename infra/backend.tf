terraform {
  backend "s3" {
    bucket         = "kp-terraform-state-prod"
    key            = "aws_data_pipeline/terraform.tfstate"
    region         = "us-east-1"
    # dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
}
