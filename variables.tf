variable "aws_region" {
  description = "AWS region to create resources in"
  type        = string
  default     = "eu-north-1"
}

variable "bucket_name" {
  description = "Globally-unique S3 bucket name to host the React site (lowercase, hyphens allowed)"
  type        = string
}