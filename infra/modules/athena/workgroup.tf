resource "aws_athena_workgroup" "datalake" {
  name = "kp_datalake_workgroup"
  configuration {
    result_configuration {
      output_location = "s3://s3-golden-bucket-kp-dev/athena-results/"
    }
  }
}
