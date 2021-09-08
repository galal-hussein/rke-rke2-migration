
variable "rancher_api_url" {
  type        = string
  description = "URL of Rancher server to use for cluster"
}

variable "rancher_token" {
  type        = string
  description = "API key to use for authentication into Rancher server (bearer token format, aka <access key>:<secret key>"
}
