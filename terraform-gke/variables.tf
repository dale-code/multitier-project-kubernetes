# =====================================================================
# variables.tf — inputs. Real values go in terraform.tfvars (gitignored).
# See terraform.tfvars.example for the template.
# =====================================================================

variable "project_id" {
  description = "GCP project ID to deploy into."
  type        = string
}

variable "region" {
  description = "GCP region for the VPC, subnet, and GKE cluster."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Primary zone for the (zonal) GKE cluster and its node pool."
  type        = string
  default     = "us-central1-a"
}

variable "cluster_name" {
  description = "Name of the GKE cluster."
  type        = string
  default     = "capstone-gke"
}

variable "node_machine_type" {
  description = "Machine type for cluster nodes. e2-medium is the cheapest type that comfortably runs all five tiers with room for rolling updates."
  type        = string
  default     = "e2-medium"
}

variable "node_min_count" {
  description = "Minimum nodes in the node pool (per zone). Cluster autoscaler will not scale below this."
  type        = number
  default     = 1
}

variable "node_max_count" {
  description = "Maximum nodes in the node pool (per zone). Keep this small on a learning project — it's a cost ceiling."
  type        = number
  default     = 3
}

variable "app_image_repo" {
  description = "Name of the Artifact Registry repository that will hold the app's container image."
  type        = string
  default     = "capstone-images"
}
