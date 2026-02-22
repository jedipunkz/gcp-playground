# Artifact Registry repository for Docker images
resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = var.service_name
  format        = "DOCKER"
  description   = "Docker images for ${var.service_name}"
}
