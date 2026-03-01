# Artifact Registry repository for all Cloud Run Job images
resource "google_artifact_registry_repository" "jobs" {
  location      = var.region
  repository_id = "${var.job_name}-jobs"
  format        = "DOCKER"
  description   = "Docker images for Cloud Run Jobs — ${var.job_name}"
}
