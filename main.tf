provider "aws" {
  region = "eu-north-1"
}

##########################################
# 1️⃣ SNS topic and email subscription
##########################################
resource "aws_sns_topic" "cost_alerts" {
  name = "cost_alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = "banreti.laszlo@gmail.com"
}

##########################################
# 2️⃣ CloudWatch billing alarm
##########################################
resource "aws_cloudwatch_metric_alarm" "billing_alarm" {
  alarm_name          = "MonthlyCostAlarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600
  statistic           = "Maximum"
  threshold           = 10
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]

  dimensions = {
    Currency = "USD"
  }
}

##########################################
# 3️⃣ S3 bucket (private) + index.html
##########################################
resource "aws_s3_bucket" "dashboard" {
  bucket = "aws-cost-dashboard-laszlobanreti"
}

resource "aws_s3_bucket_website_configuration" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id

  index_document {
    suffix = "index.html"
  }
}

# index.html upload (versioning based on etag)
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.dashboard.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"

  # gets refreshed during every apply in case of any change
  etag = filemd5("${path.module}/index.html")
}

##########################################
# 4️⃣ CloudFront distribution + OAI
##########################################
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for cost dashboard"
}

# S3 bucket policy: only CloudFront OAI is permitted to read
resource "aws_s3_bucket_policy" "dashboard_cf" {
  bucket = aws_s3_bucket.dashboard.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = aws_cloudfront_origin_access_identity.oai.iam_arn
      }
      Action   = ["s3:GetObject"]
      Resource = "${aws_s3_bucket.dashboard.arn}/*"
    }]
  })
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "dashboard" {
  enabled = true

  origin {
    domain_name = aws_s3_bucket.dashboard.bucket_regional_domain_name
    origin_id   = "s3-dashboard"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-dashboard"

    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  default_root_object = "index.html"

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

##########################################
# 5️⃣ Lambda: cost.json refresh
##########################################
resource "aws_iam_role" "lambda_role" {
  name = "lambda-cost-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# Lambda base permission (CloudWatch logs)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Cost Explorer permission + S3 write
resource "aws_iam_role_policy_attachment" "lambda_ce" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Lambda funkcion
resource "aws_lambda_function" "update_cost_json" {
  function_name = "update_cost_json"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"

  role = aws_iam_role.lambda_role.arn
  filename = "${path.module}/lambda.zip"  # python code can be found here
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")
}

##########################################
# 6️⃣ CloudWatch Event (Cron) Lambda trigger
##########################################
resource "aws_cloudwatch_event_rule" "weekly_cost_update" {
  name                = "weekly-cost-update"
  schedule_expression = "rate(7 days)"  # hetente egyszer
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.weekly_cost_update.name
  target_id = "updateCostLambda"
  arn       = aws_lambda_function.update_cost_json.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_cost_json.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_cost_update.arn
}
