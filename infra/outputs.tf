output "landing_zone_bucket" {
  description = "S3 bucket for landing raw data from DynamoDB stream"
  value       = module.s3.landing_bucket
}

output "cleansed_zone_bucket" {
  description = "S3 bucket for cleansed/processed data"
  value       = module.s3.cleansed_bucket
}

output "golden_zone_bucket" {
  description = "S3 bucket for golden/curated data"
  value       = module.s3.golden_bucket
}
