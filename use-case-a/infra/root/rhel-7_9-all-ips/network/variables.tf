
variable "aws_region" {
  type        = string
  description = "AWS region to deploy nodes"
  default     = "us-east-2"
}

# Uncomment if using AWS access key + secret key pair
///*
variable "aws_access_key" {
  type        = string
  description = "Access key used for authenticating into AWS"
}

variable "aws_secret_key" {
  type        = string
  description = "Secret key used for authenticating into AWS"
}
//*/
