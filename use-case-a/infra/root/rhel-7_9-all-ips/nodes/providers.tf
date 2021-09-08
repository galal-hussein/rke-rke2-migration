provider "aws" {
  region = var.aws_region
  # Uncomment if using AWS access key + secret key pair
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
