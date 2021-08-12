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

variable "hub_audit_dataset" {
  type    = string
  default = "audit_dataset"
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
