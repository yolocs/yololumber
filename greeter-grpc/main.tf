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

terraform {
  backend "gcs" {
    bucket = "yololumber-state"
    prefix = "default/greeter-grpc"
  }
}

resource "google_service_account" "greeter" {
  account_id  = "greeter"
  description = "Service Account for greeter"
}

resource "google_cloud_run_service" "greeter" {
  provider = google-beta
  name     = "greeter-grpc"
  location = var.region

  metadata {
    labels = {
    }
    annotations = {
      # To enable beta features, e.g. mount secrets.
      "run.googleapis.com/launch-stage" = "BETA"
    }
  }

  template {
    spec {
      service_account_name = google_service_account.greeter.email

      containers {
        image = "gcr.io/cshou-lumberjack-app/server-fa9039378379190be4d45d2fdb204ba7@sha256:94eee4dedadd8596850df260337aa5ee182ea5150b05c973f993fb36854a2041"
      }
    }
  }
  autogenerate_revision_name = true

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["client.knative.dev/user-image"],
      metadata[0].annotations["run.googleapis.com/client-name"],
      metadata[0].annotations["run.googleapis.com/client-version"],
      metadata[0].annotations["run.googleapis.com/ingress-status"],
      metadata[0].annotations["serving.knative.dev/creator"],
      metadata[0].annotations["serving.knative.dev/lastModifier"],
      metadata[0].labels["cloud.googleapis.com/location"],
      template[0].metadata[0].annotations["client.knative.dev/user-image"],
      template[0].metadata[0].annotations["run.googleapis.com/client-name"],
      template[0].metadata[0].annotations["run.googleapis.com/client-version"],
      template[0].metadata[0].annotations["run.googleapis.com/sandbox"],
      template[0].metadata[0].annotations["serving.knative.dev/creator"],
      template[0].metadata[0].annotations["serving.knative.dev/lastModifier"],
    ]
  }
}

resource "google_project_iam_member" "greeter-logging" {
  role = "roles/logging.logWriter"
  # Reference the cloud run service service account to grant access to the SQL.
  member = "serviceAccount:${google_service_account.greeter.email}"
}

