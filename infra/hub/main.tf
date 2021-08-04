variable "project" {
  type    = string
  default = "cshou-lumberjack-hub"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "stack_name" {
  type    = string
  default = "default"
}

# Google provider
provider "google" {
  project = var.project
  region  = var.region
}

# Google beta provider
provider "google-beta" {
  project = var.project
  region  = var.region
}
