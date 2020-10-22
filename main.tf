# to test: run `terraform plan`
# to deploy: run `terraform apply`

terraform {
  required_version = ">= 0.13.4"
  required_providers {
    archive = {
      version = ">= 2.0.0"
      source = "hashicorp/archive"
    }
    aws = {
      version = ">= 3.11.0"
      source = "hashicorp/aws"
    }
  }
}

variable "aws_region" {
  default = "us-east-1"
}

provider "aws" {
  profile         = "default"
  region          = var.aws_region
}

data "aws_caller_identity" "current" { }

data "archive_file" "message_dispatch_lambda_zip" {
  type          = "zip"
  source_dir    = "src"
  output_path   = "build/message_dispatch_lambda_function.zip"
}

resource "aws_lambda_function" "message_dispatch_lambda_tf" {
  filename         = "build/message_dispatch_lambda_function.zip"
  function_name    = "message_dispatch_lambda"
  role             = aws_iam_role.message_dispatch_lambda_role_tf.arn
  handler          = "message_dispatch_lambda.handler"
  source_code_hash = data.archive_file.message_dispatch_lambda_zip.output_base64sha256
  runtime          = "nodejs12.x"
  timeout          = 30
  environment {
    variables = {
      AWS_ACCOUNT_ID: data.aws_caller_identity.current.account_id
    }
  }
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

resource "aws_sqs_queue" "message_dispatch_lambda_sink_tf" {
  for_each = toset(flatten(
    [
      for key in keys(var.queue_mapping): [
        for value in lookup(var.queue_mapping, key): [
          join("_", [key, value, "queue"])
        ]
      ]
    ]
  ))
  name = each.value
  delay_seconds = 0
  max_message_size = 2048
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 0
  visibility_timeout_seconds = 30
}
