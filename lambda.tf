# to test: run `terraform plan`
# to deploy: run `terraform apply`

variable "aws_region" {
  default = "us-east-1"
}

provider "aws" {
  profile         = "default"
  region          = var.aws_region
}

data "archive_file" "message_dispatch_lambda_zip" {
    type          = "zip"
    source_file   = "src/message_dispatch_lambda.js"
    output_path   = "build/message_dispatch_lambda_function.zip"
}

resource "aws_lambda_function" "message_dispatch_lambda_tf" {
  filename         = "message_dispatch_lambda_function.zip"
  function_name    = "message_dispatch_lambda"
  role             = aws_iam_role.message_dispatch_lambda_role_tf.arn
  handler          = "message_dispatch_lambda.handler"
  source_code_hash = data.archive_file.message_dispatch_lambda_zip.output_base64sha256
  runtime          = "nodejs12.x"
  timeout          = 30
}

resource "aws_iam_role" "message_dispatch_lambda_role_tf" {
  name = "message_dispatch_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_sqs_queue" "message_dispatch_lambda_source_queue_tf" {
  name                       = "message_dispatch_lambda_source_queue"
  delay_seconds              = 0
  max_message_size           = 2048
  message_retention_seconds  = 1209600
  receive_wait_time_seconds  = 10
  visibility_timeout_seconds = 30
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.message_dispatch_lambda_source_dlq_tf.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "message_dispatch_lambda_source_dlq_tf" {
  name                       = "message_dispatch_lambda_source_dlq"
  delay_seconds              = 0
  max_message_size           = 2048
  message_retention_seconds  = 1209600
  receive_wait_time_seconds  = 0
  visibility_timeout_seconds = 30
}
