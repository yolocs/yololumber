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
    prefix = "default/cowsay"
  }
}

resource "google_service_account" "cowsay" {
  account_id  = "cowsay"
  description = "Service Account for cowsay"
}

resource "google_cloud_run_service" "cowsay" {
  provider = google-beta
  name     = "cowsay"
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
    metadata {
      annotations = {
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.name
        "run.googleapis.com/vpc-access-egress"    = "private-ranges-only"
        "run.googleapis.com/cloudsql-instances"   = "${google_sql_database_instance.cowsay.connection_name}"
      }
    }

    spec {
      service_account_name = google_service_account.cowsay.email

      containers {
        image = "gcr.io/cshou-lumberjack-app/rundemo-b07b2bb657207519b0b9b53562604426@sha256:360eae3e0e2189047fc1f4700cd1675cc4bcc1cf4ecdd2467f7d81d2b7d63d8b"
        env {
          name  = "REDIS_HOST"
          value = google_redis_instance.cache.host
        }
        env {
          name  = "REDIS_PORT"
          value = google_redis_instance.cache.port
        }
        env {
          name  = "DB_NAME"
          value = "default"
        }
        env {
          name  = "DB_USER"
          value = "default"
        }
        env {
          name = "DB_PASS"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.cowsay-default.secret_id
              key  = "1"
            }
          }
        }
        env {
          name  = "DB_SOCKET"
          value = "/cloudsql/${google_sql_database_instance.cowsay.connection_name}"
        }
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

resource "google_compute_network" "cowsay" {
  name = "cowsay"
}

resource "google_vpc_access_connector" "connector" {
  name          = "cowsay-con"
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.cowsay.name
}

resource "google_redis_instance" "cache" {
  name               = "cowsay"
  memory_size_gb     = 1
  authorized_network = google_compute_network.cowsay.id
}

resource "google_sql_database_instance" "cowsay" {
  name                = "cowsay"
  database_version    = "POSTGRES_11"
  deletion_protection = false

  settings {
    tier = "db-f1-micro"
    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }
    database_flags {
      name  = "pgaudit.log"
      value = "all"
    }
  }
}

resource "google_sql_database" "cowsay-default" {
  name     = "default"
  instance = google_sql_database_instance.cowsay.name
}

resource "google_sql_user" "cowsay-default" {
  name     = "default"
  instance = google_sql_database_instance.cowsay.name
  password = random_password.cowsay-default.result
}

resource "random_password" "cowsay-default" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "google_secret_manager_secret" "cowsay-default" {
  secret_id = "cowsay-default"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "cowsay-default" {
  secret      = google_secret_manager_secret.cowsay-default.id
  secret_data = random_password.cowsay-default.result
}

resource "google_project_iam_member" "cowsay" {
  role = "roles/cloudsql.client"
  # Reference the cloud run service service account to grant access to the SQL.
  member = "serviceAccount:${google_service_account.cowsay.email}"
}

resource "google_project_iam_member" "cowsay-logging" {
  role = "roles/logging.logWriter"
  # Reference the cloud run service service account to grant access to the SQL.
  member = "serviceAccount:${google_service_account.cowsay.email}"
}

resource "google_secret_manager_secret_iam_member" "cowsay-default" {
  secret_id = google_secret_manager_secret_version.cowsay-default.secret
  role      = "roles/secretmanager.secretAccessor"
  # Reference the cloud run service service account to grant access to the secret.
  member = "serviceAccount:${google_service_account.cowsay.email}"
}

