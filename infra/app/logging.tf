resource "google_project_service" "project_logging" {
  service            = "logging.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_iam_audit_config" "audit_logging" {
  service = "allServices"
  audit_log_config {
    log_type         = "ADMIN_READ"
    exempted_members = var.exempted_members
  }
  # audit_log_config {
  #   log_type = "ADMIN_WRITE"
  # }
  audit_log_config {
    log_type         = "DATA_READ"
    exempted_members = var.exempted_members
  }
  audit_log_config {
    log_type         = "DATA_WRITE"
    exempted_members = var.exempted_members
  }
}

resource "google_logging_project_sink" "infra_audit_log_sink" {
  name                   = "infra-audit-sink-${var.stack_name}"
  destination            = "pubsub.googleapis.com/projects/${var.hub_project}/topics/${var.hub_log_channel}"
  filter                 = "LOG_ID(\"cloudaudit.googleapis.com/activity\") OR LOG_ID(\"cloudaudit.googleapis.com/data_access\") OR LOG_ID(\"cloudaudit.googleapis.com/system_event\") OR LOG_ID(\"cloudaudit.googleapis.com/access_transparency\")"
  unique_writer_identity = true
}

resource "google_logging_project_sink" "app_audit_log_sink" {
  name        = "app-audit-sink-${var.stack_name}"
  destination = "pubsub.googleapis.com/projects/${var.hub_project}/topics/${var.hub_log_channel}"
  # Should probably create our own proto type and use that for filter.
  filter                 = "logName : \"lumberjack-auditlog\""
  unique_writer_identity = true
}

resource "google_pubsub_topic_iam_member" "infra_sink_member" {
  project = var.hub_project
  topic   = var.hub_log_channel
  role    = "roles/pubsub.publisher"
  member  = google_logging_project_sink.infra_audit_log_sink.writer_identity
}

resource "google_pubsub_topic_iam_member" "app_sink_member" {
  project = var.hub_project
  topic   = var.hub_log_channel
  role    = "roles/pubsub.publisher"
  member  = google_logging_project_sink.app_audit_log_sink.writer_identity
}
