resource "google_pubsub_topic" "log_channel" {
  name = "log-channel-${var.stack_name}"

  labels = {
    "stack" = var.stack_name
  }
}

resource "google_service_account" "logpub" {
  account_id  = "logpub-${var.stack_name}"
  description = "The service account used to push logs"
}

resource "google_cloud_run_service_iam_member" "member" {
  location = google_cloud_run_service.logwriter.location
  project  = google_cloud_run_service.logwriter.project
  service  = google_cloud_run_service.logwriter.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.logpub.email}"
}

resource "google_pubsub_subscription" "log_subscription" {
  name  = "log-subscription-${var.stack_name}"
  topic = google_pubsub_topic.log_channel.name

  ack_deadline_seconds = 30

  labels = {
    "stack" = var.stack_name
  }

  push_config {
    push_endpoint = "${google_cloud_run_service.logwriter.status[0].url}/logs"
    oidc_token {
      service_account_email = google_service_account.logpub.email
    }
  }
}

resource "google_spanner_instance" "log_storage" {
  name         = "logs-${var.stack_name}"
  config       = "nam6"
  display_name = "Log storage"
  num_nodes    = 2
  labels = {
    "stack" = var.stack_name
  }
}

resource "google_spanner_database" "log_database" {
  instance = google_spanner_instance.log_storage.name
  name     = "log-db-${var.stack_name}"
  ddl = [
    "CREATE TABLE Logs (id STRING(MAX) NOT NULL, time TIMESTAMP NOT NULL, payload STRING(MAX) NOT NULL) PRIMARY KEY(id)",
  ]
}

resource "google_service_account" "logwriter" {
  account_id  = "logwriter-${var.stack_name}"
  description = "Service Account for logwriter"
}

resource "google_spanner_database_iam_member" "database" {
  instance = google_spanner_instance.log_storage.name
  database = google_spanner_database.log_database.name
  role     = "roles/spanner.databaseUser"
  member   = "serviceAccount:${google_service_account.logwriter.email}"
}

resource "google_cloud_run_service" "logwriter" {
  provider = google-beta
  name     = "logwriter-${var.stack_name}"
  location = var.region

  metadata {
    labels = {
      "stack" = var.stack_name
    }
    annotations = {
      # To enable beta features, e.g. mount secrets.
      "run.googleapis.com/launch-stage" = "BETA"
    }
  }

  template {
    spec {
      service_account_name = google_service_account.logwriter.email

      containers {
        image = "gcr.io/cshou-lumberjack-hub/logwriter-f7687059a7faefdbb4cbb83397a3e4c4@sha256:e6bcd0b7aa130f6090e072eeaf50f856b859767c9e41448bdb1df99a77fd23bc"
        env {
          name  = "SPANNER_DB"
          value = "projects/${var.project}/instances/${google_spanner_instance.log_storage.name}/databases/${google_spanner_database.log_database.name}"
        }
        env {
          name  = "INSERT_FAKE_LOGS"
          value = "true"
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
