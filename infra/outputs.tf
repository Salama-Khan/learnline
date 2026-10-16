output "raw_bucket_name" {
  description = "Name of the raw data bucket"
  value       = aws_s3_bucket.raw.bucket
}