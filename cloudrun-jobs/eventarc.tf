# ---------------------------------------------------------------------------
# GCS input bucket — uploading a file here triggers the event-processor job
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "input" {
  name                        = "${var.project_id}-${var.job_name}-input"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30 # auto-delete processed objects after 30 days
    }
    action {
      type = "Delete"
    }
  }
}

# ---------------------------------------------------------------------------
# Eventarc trigger for Pattern 3 (Event-driven)
#
# Flow: GCS object uploaded → GCS publishes to Pub/Sub → Eventarc receives
#       → Eventarc executes the event-processor Cloud Run Job
#
# Notes:
#   - Eventarc passes event metadata to the job as CloudEvents HTTP headers
#     (ce-id, ce-source, ce-type, ce-subject, etc.) via container overrides.
#   - The job container should read these to identify which object to process.
#   - depends_on ensures IAM propagates before the trigger is created,
#     avoiding intermittent permission errors on first apply.
# ---------------------------------------------------------------------------
resource "google_eventarc_trigger" "gcs_to_job" {
  name     = "${var.job_name}-gcs-trigger"
  location = var.region

  # Listen for GCS object-finalized events in the input bucket
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }

  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.input.name
  }

  # Route events to the Cloud Run Job (not a Service)
  destination {
    run_job {
      job    = google_cloud_run_v2_job.event_processor.name
      region = var.region
    }
  }

  service_account = google_service_account.eventarc.email

  depends_on = [
    google_project_iam_member.eventarc_event_receiver,
    google_cloud_run_v2_job_iam_member.eventarc_invoker,
    google_project_iam_member.gcs_pubsub_publisher,
  ]
}
