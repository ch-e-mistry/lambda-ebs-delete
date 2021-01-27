variable "region" {
  type        = string
  default     = "eu-west-1"
  description = "AWS region. Where to deploy with this Infrastructure-As-A-Code - terraform."
}

variable "profile" {
  type        = string
  default     = "default"
  description = "AWS Credential(s) profile. Define the name of the profile as defined in your aws credentials file."
}

variable "shared_credentials_file" {
  type        = string
  default     = "./secrets/credentials"
  description = "**PRE-REQUIRED!** Path of your AWS credentials file. Do NOT store it under version control system!"
}

variable "aws-lambda-function-timeout" {
  type        = number
  default     = "60"
  description = "Timeout after lambda function will exit. In sec(s)"
}

variable "aws-lambda-function-memory" {
  type        = number
  default     = "128"
  description = "Maximum allowed memory for the lambda function in MB."
}

variable "aws-lambda-function-runtime" {
  type        = string
  default     = "python3.8"
  description = "Select runtime engine provided by lambda service."
}

variable "aws-cloudwatch-event-rule-schedule-expression" {
  type        = string
  default     = "cron(0 3 * * ? *)"
  description = "Select runtime engine provided by lambda service."
}
locals {
  # Common tags to be assigned to all resources
  common_tags = {
    Name       = "ebs-delete-python",
    Automation = "Yes"
    Cost       = "cleanup"
  }
}