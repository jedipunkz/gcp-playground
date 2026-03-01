# ---------------------------------------------------------------------------
# Pattern 1: Batch ETL — execution service account
# Needs: Secret Manager (DB creds), logging, tracing, VPC (Cloud SQL)
# ---------------------------------------------------------------------------
resource "google_service_account" "batch_etl" {
  account_id   = "${var.job_name}-batch-etl"
  display_name = "Cloud Run Job SA — batch-etl"
}

resource "google_project_iam_member" "batch_etl_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.batch_etl.email}"
}

resource "google_project_iam_member" "batch_etl_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.batch_etl.email}"
}

# Secret Manager: access DB password stored as a secret
resource "google_project_iam_member" "batch_etl_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.batch_etl.email}"
}

# ---------------------------------------------------------------------------
# Pattern 2: Parallel fan-out — execution service account
# Needs: logging, tracing (no VPC required for this example)
# ---------------------------------------------------------------------------
resource "google_service_account" "parallel" {
  account_id   = "${var.job_name}-parallel"
  display_name = "Cloud Run Job SA — parallel"
}

resource "google_project_iam_member" "parallel_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.parallel.email}"
}

resource "google_project_iam_member" "parallel_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.parallel.email}"
}

# ---------------------------------------------------------------------------
# Pattern 3: Event-driven — execution service account
# Needs: read from input GCS bucket, logging, tracing
# ---------------------------------------------------------------------------
resource "google_service_account" "event_processor" {
  account_id   = "${var.job_name}-event-proc"
  display_name = "Cloud Run Job SA — event-processor"
}

resource "google_project_iam_member" "event_processor_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.event_processor.email}"
}

resource "google_project_iam_member" "event_processor_trace" {
  project = var.project_id
  role    = "roles/cloudtrace.agent"
  member  = "serviceAccount:${google_service_account.event_processor.email}"
}

# Grant read access to the input bucket that triggers the job
resource "google_storage_bucket_iam_member" "event_processor_input_reader" {
  bucket = google_storage_bucket.input.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.event_processor.email}"
}

# ---------------------------------------------------------------------------
# Cloud Scheduler service account
# Purpose: call the Cloud Run Admin API to execute the batch-etl job
# ---------------------------------------------------------------------------
resource "google_service_account" "scheduler" {
  account_id   = "${var.job_name}-scheduler"
  display_name = "Cloud Scheduler SA — batch-etl trigger"
}

# Job-scoped invoker: Scheduler can only trigger this specific job
resource "google_cloud_run_v2_job_iam_member" "scheduler_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.batch_etl.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

# ---------------------------------------------------------------------------
# Eventarc service account
# Purpose: receive GCS events and trigger the event-processor job
# ---------------------------------------------------------------------------
resource "google_service_account" "eventarc" {
  account_id   = "${var.job_name}-eventarc"
  display_name = "Eventarc SA — event-processor trigger"
}

resource "google_project_iam_member" "eventarc_event_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.eventarc.email}"
}

# Job-scoped invoker: Eventarc can only trigger this specific job
resource "google_cloud_run_v2_job_iam_member" "eventarc_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_job.event_processor.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.eventarc.email}"
}

# GCS service account must be able to publish to Pub/Sub for Eventarc to
# receive object-finalized events from Cloud Storage
data "google_storage_project_service_account" "gcs" {}

resource "google_project_iam_member" "gcs_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs.email_address}"
}
