module "lumberjack_hub" {
  source = "../../../app"

  stack_name = "default"
  exempted_members = [
    "user:cshou@google.com",
    "serviceAccount:gceenforcer@system.gserviceaccount.com",
    "serviceAccount:one-platform-tenant-manager@system.gserviceaccount.com",
    "serviceAccount:service-193399633267@compute-system.iam.gserviceaccount.com",
  ]
}

terraform {
  backend "gcs" {
    bucket = "yololumber-state"
    prefix = "default/app"
  }
}
