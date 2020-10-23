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

variable "aws_partition" {
  default = "aws"
}

variable "aws_region" {
  default = "us-east-1"
}

provider "aws" {
  profile         = "default"
  region          = var.aws_region
}

data "aws_caller_identity" "current" { }

data "archive_file" "message_dispatch_libs_zip" {
  type          = "zip"
  source_dir    = "node_modules"
  output_path   = "build/message_dispatch_lambda_libs.zip"
}

resource "aws_lambda_layer_version" "message_dispatch_lambda_libs_tf" {
  filename   = "build/message_dispatch_lambda_libs.zip"
  layer_name = "message_dispatch_lambda_libs"

  compatible_runtimes = ["nodejs12.x"]
}

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
  layers = [
    aws_lambda_layer_version.message_dispatch_lambda_libs_tf.arn
  ]
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

data "aws_iam_policy_document" "message_dispatch_lambda_policy_doc_tf" {
  statement {
    actions   = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    effect = "Allow"
    resources = [
      "arn:${var.aws_partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }
  statement {
    actions   = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:ReEncrypt*"
    ]
    effect = "Allow"
    resources = [
      aws_kms_key.message_dispatch_queue_kms.arn
    ]
  }
  statement {
    actions   = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
      "sqs:SendMessage"
    ]
    effect = "Allow"
    resources = [
      "arn:${var.aws_partition}:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
    ]
  }
}

resource "aws_iam_policy" "message_dispatch_lambda_policy_tf" {
  name        = "message_dispatch_lambda_policy"
  path        = "/"
  description = "Permissions for message dispatch lambda."
  policy      = data.aws_iam_policy_document.message_dispatch_lambda_policy_doc_tf.json
}

resource "aws_iam_policy_attachment" "message_dispatch_lambda_policy_attachment_tf" {
  name       = "test-message_dispatch_lambda_policy_attachment"
  roles      = [aws_iam_role.message_dispatch_lambda_role_tf.name]
  policy_arn = aws_iam_policy.message_dispatch_lambda_policy_tf.arn
}

data aws_iam_policy_document "default_queue_policy_doc_tf" {
  statement {
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage",
      "sqs:SendMessage"
    ]
    effect = "Allow"
    principals {
      identifiers = [
        aws_iam_role.message_dispatch_lambda_role_tf.arn
      ]
      type = "AWS"
    }
    resources = ["*"]
  }
  depends_on = [aws_iam_role.message_dispatch_lambda_role_tf]
}

resource "aws_sqs_queue" "message_dispatch_lambda_source_queue_tf" {
  name                       = "message_dispatch_lambda_source_queue"
  delay_seconds              = 0
  kms_master_key_id          = aws_kms_key.message_dispatch_queue_kms.id
  max_message_size           = 2048
  message_retention_seconds  = 1209600
  receive_wait_time_seconds  = 10
  visibility_timeout_seconds = 30
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.message_dispatch_lambda_source_dlq_tf.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue_policy" "message_dispatch_lambda_source_queue_policy_tf" {
  policy = data.aws_iam_policy_document.default_queue_policy_doc_tf.json
  queue_url = aws_sqs_queue.message_dispatch_lambda_source_queue_tf.id
}

resource "aws_sqs_queue" "message_dispatch_lambda_source_dlq_tf" {
  name                       = "message_dispatch_lambda_source_dlq"
  delay_seconds              = 0
  kms_master_key_id          = aws_kms_key.message_dispatch_queue_kms.id
  max_message_size           = 2048
  message_retention_seconds  = 1209600
  receive_wait_time_seconds  = 0
  visibility_timeout_seconds = 30
}

resource "aws_sqs_queue_policy" "message_dispatch_lambda_source_dlq_policy_tf" {
  policy = data.aws_iam_policy_document.default_queue_policy_doc_tf.json
  queue_url = aws_sqs_queue.message_dispatch_lambda_source_dlq_tf.id
}

resource "aws_lambda_event_source_mapping" "message_dispatch_lambda_source_mapping_tf" {
  batch_size = 1
  enabled = true
  event_source_arn = aws_sqs_queue.message_dispatch_lambda_source_queue_tf.arn
  function_name    = aws_lambda_function.message_dispatch_lambda_tf.arn
  depends_on = [aws_iam_policy.message_dispatch_lambda_policy_tf]
}

resource "aws_sqs_queue_policy" "message_dispatch_lambda_sink_policy_tf" {
  for_each = aws_sqs_queue.message_dispatch_lambda_sink_tf
  policy = data.aws_iam_policy_document.default_queue_policy_doc_tf.json
  queue_url = each.value.id
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
  kms_master_key_id = aws_kms_key.message_dispatch_queue_kms.id
  max_message_size = 2048
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 0
  visibility_timeout_seconds = 30
}

data "aws_iam_policy_document" "default_kms_policy_doc_tf" {
  statement {
    actions   = ["kms:*"]
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${var.aws_partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }
  statement {
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]
    effect = "Allow"
    principals {
      identifiers = ["sqs.amazonaws.com"]
      type = "Service"
    }
    resources = ["*"]
  }
  statement {
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]
    effect = "Allow"
    principals {
      identifiers = [aws_iam_role.message_dispatch_lambda_role_tf.arn]
      type = "AWS"
    }
    resources = ["*"]
  }
}

resource "aws_kms_key" "message_dispatch_queue_kms" {
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  description              = "Message dispatch queue kms keys."
  deletion_window_in_days  = 30
  enable_key_rotation      = true
  is_enabled               = true
  key_usage                = "ENCRYPT_DECRYPT"
  policy                   = data.aws_iam_policy_document.default_kms_policy_doc_tf.json
}
