module "lumberjack_hub" {
  source = "../../../hub"

  stack_name = "default"
}

terraform {
  backend "gcs" {
    bucket = "yololumber-state"
    prefix = "default/hub"
  }
}
