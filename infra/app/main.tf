variable "project" {
  type    = string
  default = "cshou-lumberjack-app"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "stack_name" {
  type    = string
  default = "default"
}

variable "exempted_members" {
  type    = list(string)
  default = []
}

variable "hub_project" {
  type    = string
  default = "cshou-lumberjack-hub"
}

variable "hub_log_channel" {
  type    = string
  default = "log-channel-default"
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
