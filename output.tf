output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.site.bucket
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name (use HTTPS)"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution id (for invalidations)"
  value       = aws_cloudfront_distribution.cdn.id
}