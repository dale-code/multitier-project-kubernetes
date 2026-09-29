resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone # zonal cluster: cheaper and faster to create than regional, fine for a learning project

  network    = google_compute_network.vpc.id
  subnetwork = google_compute_subnetwork.subnet.id

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  
  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false # so `terraform destroy` in Phase 3 actually leaves nothing billable

  depends_on = [google_project_service.required_apis]
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "${var.cluster_name}-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  autoscaling {
    min_node_count = var.node_min_count
    max_node_count = var.node_max_count
  }

  management {
    auto_repair  = true # node-level self-healing: GKE replaces nodes that fail health checks
    auto_upgrade = true
  }

  node_config {
    machine_type = var.node_machine_type
    tags         = ["capstone-node"] # matches the firewall target_tags in network.tf

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only", # pull images from Artifact Registry
    ]

    labels = {
      env = "capstone"
    }
  }
}

# Somewhere for the app's container image to live. Build+push with:
#   gcloud auth configure-docker <region>-docker.pkg.dev
#   docker build -t <region>-docker.pkg.dev/<project>/<repo>/capstone-app:v1 ./app
#   docker push <region>-docker.pkg.dev/<project>/<repo>/capstone-app:v1
resource "google_artifact_registry_repository" "app_images" {
  location      = var.region
  repository_id = var.app_image_repo
  format        = "DOCKER"
  description   = "Container images for the capstone app tier"

  depends_on = [google_project_service.required_apis]
}
