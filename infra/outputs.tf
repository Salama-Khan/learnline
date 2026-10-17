output "raw_bucket_name" {
  description = "Name of the raw data bucket"
  value       = aws_s3_bucket.raw.bucket
}

output "clean_bucket_name" {
  value = aws_s3_bucket.clean.bucket
}

output "athena_results_bucket_name" {
  value = aws_s3_bucket.athena_results.bucket
}

output "glue_database_name" {
  value = aws_glue_catalog_database.main.name
}

output "athena_workgroup_name" {
  value = aws_athena_workgroup.main.name
}