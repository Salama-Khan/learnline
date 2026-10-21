data "archive_file" "ingest" {
  type        = "zip"
  source_dir  = "${path.module}/../src/ingest"
  output_path = "${path.module}/build/ingest.zip"
  excludes    = ["__pycache__"]
}

resource "aws_iam_role" "ingest" {
  name = "${var.project}-ingest-dfe"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "ingest" {
  name = "write-raw-dfe-and-logs"
  role = aws_iam_role.ingest.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.raw.arn}/dfe/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.ingest.arn}:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "ingest" {
  name              = "/aws/lambda/${var.project}-ingest-dfe"
  retention_in_days = 14
}

resource "aws_lambda_function" "ingest" {
  function_name    = "${var.project}-ingest-dfe"
  role             = aws_iam_role.ingest.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.ingest.output_path
  source_code_hash = data.archive_file.ingest.output_base64sha256
  timeout          = 60
  memory_size      = 256

  environment {
    variables = {
      RAW_BUCKET = aws_s3_bucket.raw.bucket
    }
  }

  depends_on = [aws_cloudwatch_log_group.ingest]
}