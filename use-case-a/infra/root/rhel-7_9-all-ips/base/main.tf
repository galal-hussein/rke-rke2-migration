resource "random_string" "main" {
  length = 6

  lower   = true
  number  = false
  special = false
  upper   = false
}
