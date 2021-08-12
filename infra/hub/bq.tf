resource "google_bigquery_dataset" "log_dataset" {
  dataset_id    = "audit_dataset"
  friendly_name = "Audit Dataset"
  description   = "Audit Dataset"
  location      = "US"

  labels = {
    "stack" = var.stack_name
  }
}
