terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.40"
    }
  }

  # --- Where Terraform state lives -----------------------------------
  # Local state (default, no backend block) is fine for a solo learning
  # project — but it means the state file lives on whichever machine ran
  # `apply` and must NEVER be committed (see .gitignore: *.tfstate*).
  #
  # For anything beyond a single-person/single-machine setup, uncomment
  # the GCS backend below (a stretch goal in PROJECT-SPEC.md section 9).
  # The bucket must exist BEFORE you run `terraform init` with this
  # block uncommented — Terraform won't create its own state bucket.
  #
  # backend "gcs" {
  #   bucket = "YOUR-terraform-state-bucket"
  #   prefix = "capstone/gke"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
