terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region                  = var.region
  shared_credentials_file = var.shared_credentials_file
  profile                 = var.profile
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "python-ebs-delete-role"
  tags          = {
    Name = "ebs-delete-python",
    Automation = "Yes"
    Cost = "cleanup"
  }

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

resource "aws_iam_policy" "policy" {
  name        = "python-ebs-delete-policy"
  description = "A test policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "cloudtrail:LookupEvents",
                "logs:CreateLogStream",
                "ec2:DescribeVolumeStatus",
                "cloudtrail:StartLogging",
                "ec2:DescribeVolumes",
                "cloudtrail:CreateTrail",
                "cloudtrail:GetTrailStatus",
                "ec2:DescribeVolumesModifications",
                "logs:CreateLogGroup",
                "logs:PutLogEvents",
                "ec2:DescribeVolumeAttribute",
                "cloudtrail:DescribeTrails"
            ],
            "Resource": "*"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "ec2:DeleteVolume",
            "Resource": "arn:aws:ec2:*:909993075274:volume/*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.policy.arn
}

data "archive_file" "lambda_zip" {
    type        = "zip"
    source_dir  = "lambda"
    output_path = "python-ebs-delete.zip"
}

resource "aws_lambda_function" "test_lambda" {
  filename      = "python-ebs-delete.zip"
  function_name = "python-ebs-delete"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "python-ebs-delete.lambda_handler"
  timeout       = "60"
  memory_size   = "128"
  tags          = {
    Name = "ebs-delete-python",
    Automation = "Yes"
    Cost = "cleanup"
  }

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime = "python3.8"

  environment {
    variables = {
      IGNORE_WINDOW = "1"
    }
  }
}
resource "aws_cloudwatch_event_rule" "UTC3" {
  name                = "UTC_0300"
  description         = "Schedule at 03:00 UTC"
  schedule_expression = "cron(0 3 * * ? *)"
}

resource "aws_cloudwatch_event_target" "test_lambda_UTC3" {
  rule      = "${aws_cloudwatch_event_rule.UTC3.name}"
  target_id = "lambda"
  arn       =  aws_lambda_function.test_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_test_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.UTC3.arn}"
}