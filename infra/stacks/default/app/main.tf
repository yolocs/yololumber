module "lumberjack_hub" {
  source = "../../../app"

  stack_name = "default"
  exempted_members = [
    "serviceAccount:cowsay@cshou-lumberjack-app.iam.gserviceaccount.com",
    "user:cshou@google.com",
    "serviceAccount:gceenforcer@system.gserviceaccount.com",
    "serviceAccount:one-platform-tenant-manager@system.gserviceaccount.com",
  ]
}

terraform {
  backend "gcs" {
    bucket = "yololumber-state"
    prefix = "default/app"
  }
}