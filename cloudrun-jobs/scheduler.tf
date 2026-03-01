# ---------------------------------------------------------------------------
# Cloud Scheduler trigger for Pattern 1 (Scheduled Batch ETL)
#
# Cloud Scheduler calls the Cloud Run Admin API with an OAuth 2.0 token
# (not OIDC — the target is a Google API endpoint, not a Cloud Run URL).
# The Scheduler SA has roles/run.invoker scoped to this job only.
# ---------------------------------------------------------------------------
resource "google_cloud_scheduler_job" "batch_etl" {
  name             = "${var.job_name}-batch-etl-trigger"
  description      = "Nightly trigger for the batch-etl Cloud Run Job"
  schedule         = var.batch_schedule
  time_zone        = var.batch_schedule_timezone
  region           = var.region
  attempt_deadline = "320s" # max time Cloud Scheduler waits for HTTP 2xx

  retry_config {
    retry_count          = 1
    min_backoff_duration = "5s"
    max_backoff_duration = "3600s"
  }

  http_target {
    http_method = "POST"

    # Cloud Run Admin API endpoint to execute a job
    uri = "https://run.googleapis.com/v2/projects/${var.project_id}/locations/${var.region}/jobs/${google_cloud_run_v2_job.batch_etl.name}:run"

    # Use OAuth 2.0 (not OIDC) when calling Google APIs
    oauth_token {
      service_account_email = google_service_account.scheduler.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }
}
