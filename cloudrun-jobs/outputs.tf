output "artifact_registry_url" {
  description = "Artifact Registry URL prefix — append /<image-name>:<tag> when building"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.jobs.repository_id}"
}

# ---------------------------------------------------------------------------
# Pattern 1: Scheduled Batch ETL
# ---------------------------------------------------------------------------
output "batch_etl_job_id" {
  description = "Fully qualified resource ID of the batch-etl job"
  value       = google_cloud_run_v2_job.batch_etl.id
}

output "batch_etl_manual_trigger" {
  description = "gcloud command to manually trigger the batch-etl job"
  value       = "gcloud run jobs execute ${google_cloud_run_v2_job.batch_etl.name} --region ${var.region} --wait"
}

# ---------------------------------------------------------------------------
# Pattern 2: Parallel Fan-out
# ---------------------------------------------------------------------------
output "parallel_job_id" {
  description = "Fully qualified resource ID of the parallel fan-out job"
  value       = google_cloud_run_v2_job.parallel.id
}

output "parallel_manual_trigger" {
  description = "gcloud command to manually trigger the parallel job"
  value       = "gcloud run jobs execute ${google_cloud_run_v2_job.parallel.name} --region ${var.region} --wait"
}

# ---------------------------------------------------------------------------
# Pattern 3: Event-driven
# ---------------------------------------------------------------------------
output "event_processor_job_id" {
  description = "Fully qualified resource ID of the event-processor job"
  value       = google_cloud_run_v2_job.event_processor.id
}

output "input_bucket_name" {
  description = "GCS bucket — uploading any object here triggers the event-processor job"
  value       = google_storage_bucket.input.name
}

output "event_processor_manual_trigger" {
  description = "gcloud command to manually trigger the event-processor job"
  value       = "gcloud run jobs execute ${google_cloud_run_v2_job.event_processor.name} --region ${var.region} --wait"
}
