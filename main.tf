terraform {
  required_version = ">= 1.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# -------------------------
# S3 bucket (private)
# -------------------------
resource "aws_s3_bucket" "site" {
  bucket = var.bucket_name

  tags = {
    Name = var.bucket_name
    Env  = "prod"
  }

  # Prevent accidental deletion in some workflows - optional:
  # lifecycle {
  #   prevent_destroy = true
  # }
}

# Block public access at bucket level
resource "aws_s3_bucket_public_access_block" "block" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# (Optional) website configuration is NOT required for CloudFront origin; we rely on REST API origin.
# But CloudFront default_root_object = "index.html" below will serve SPA root.
# -------------------------

# -------------------------
# Origin Access Identity (OAI)
# -------------------------
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for ${var.bucket_name}"
}

# -------------------------
# S3 bucket policy to allow only CloudFront OAI to GetObject
# -------------------------
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid    = "AllowCloudFrontGetObject"
    effect = "Allow"

    principals {
      # Use the canonical user id for the OAI
      type        = "CanonicalUser"
      identifiers = [aws_cloudfront_origin_access_identity.oai.s3_canonical_user_id]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "site_policy" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# -------------------------
# CloudFront Distribution (REST S3 origin, OAI)
# -------------------------
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id   = "s3-${aws_s3_bucket.site.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-${aws_s3_bucket.site.id}"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # Serve index.html for SPA routes on 403/404 (common for React SPA)
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.bucket_name}-cdn"
  }
}