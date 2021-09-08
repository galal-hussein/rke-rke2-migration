variable "network_name" {
  type        = string
  description = "Identifier used to label all named resources"
}

variable "extra_tags" {
  type        = map(string)
  description = "Extra tags to add to all resources"
  default     = {}
}

