variable "region" {
  type        = string
  default     = "us-east-1"
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