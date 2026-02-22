output "load_balancer_ip" {
  description = "Global static IP of the HTTPS load balancer. Point your DNS A record here."
  value       = google_compute_global_address.default.address
}

output "cloud_run_prod_url" {
  description = "Direct Cloud Run URL of the production service (ingress: LB only)"
  value       = google_cloud_run_v2_service.app.uri
}

output "cloud_run_staging_url" {
  description = "Direct Cloud Run URL of the staging service"
  value       = google_cloud_run_v2_service.staging.uri
}

output "artifact_registry_url" {
  description = "Artifact Registry Docker repository URL (use as image prefix)"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}"
}

output "clouddeploy_pipeline" {
  description = "Cloud Deploy delivery pipeline name"
  value       = google_clouddeploy_delivery_pipeline.app.name
}
