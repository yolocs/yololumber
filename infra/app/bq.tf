resource "google_logging_project_sink" "infra_bq_sink" {
  name                   = "infra-bq-${var.stack_name}"
  destination            = "bigquery.googleapis.com/projects/${var.hub_project}/datasets/${var.hub_audit_dataset}"
  filter                 = "LOG_ID(\"cloudaudit.googleapis.com/activity\") OR LOG_ID(\"cloudaudit.googleapis.com/data_access\") OR LOG_ID(\"cloudaudit.googleapis.com/system_event\") OR LOG_ID(\"cloudaudit.googleapis.com/access_transparency\")"
  unique_writer_identity = true
  bigquery_options {
    use_partitioned_tables = true
  }
}

resource "google_logging_project_sink" "app_bq_sink" {
  name        = "app-bq-${var.stack_name}"
  destination = "bigquery.googleapis.com/projects/${var.hub_project}/datasets/${var.hub_audit_dataset}"
  # Should probably create our own proto type and use that for filter.
  filter                 = "logName : \"lumberjack-auditlog\""
  unique_writer_identity = true
  bigquery_options {
    use_partitioned_tables = true
  }
}

resource "google_bigquery_dataset_iam_member" "infra_bq_memeber" {
  dataset_id = var.hub_audit_dataset
  project    = var.hub_project
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.infra_bq_sink.writer_identity
}

resource "google_bigquery_dataset_iam_member" "app_bq_memeber" {
  dataset_id = var.hub_audit_dataset
  project    = var.hub_project
  role       = "roles/bigquery.dataEditor"
  member     = google_logging_project_sink.app_bq_sink.writer_identity
}
