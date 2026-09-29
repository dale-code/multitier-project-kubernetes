# =====================================================================
# network.tf — dedicated VPC + subnet for the cluster.
# =====================================================================
# Why a dedicated VPC instead of "default"? The "default" network in a
# fresh GCP project auto-creates permissive firewall rules (e.g. allowing
# broad internal traffic and 0.0.0.0/0 on some ports). PROJECT-SPEC.md's
# security section is explicit: only the proxy is public, everything
# else stays internal. Starting from an empty, purpose-built VPC means
# every open port is one WE decided to open, not something GCP defaulted
# for us. This is the Kubernetes-world equivalent of the VM approach's
# "which ports to open, and which stay internal" requirement.

resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "vpc" {
  name                    = "capstone-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.required_apis]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "capstone-subnet"
  ip_cidr_range = "10.10.0.0/20"
  region        = var.region
  network       = google_compute_network.vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/14"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.30.0.0/20"
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["capstone-node"]
}
