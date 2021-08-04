variable "project" {
  type    = string
  default = "cshou-lumberjack-app"
}

variable "region" {
  type    = string
  default = "us-central1"
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
