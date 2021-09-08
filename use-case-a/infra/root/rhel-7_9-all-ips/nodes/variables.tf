
variable "aws_region" {
  type        = string
  description = "AWS region to deploy nodes"
  default     = "us-east-2"
}

# Comment or remove if using local AWS CLI config
variable "aws_access_key" {
  type        = string
  description = "Access key used for authenticating into AWS"
}

# Comment or remove if using local AWS CLI config
variable "aws_secret_key" {
  type        = string
  description = "Secret key used for authenticating into AWS"
}

variable "aws_ami_prefix" {
  type        = string
  description = "Prefix to filter AMIs on"
  default     = "RHEL-7.9_HVM_GA-"
}

variable "aws_ami_owner" {
  type        = string
  description = "Owner to filter AMIs on; defaults to Red Hat in AWS Commercial"
  default     = "309956199498"
}
