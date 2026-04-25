# ---------------------------------------------------------------------------
# Cloud Run service account
# ---------------------------------------------------------------------------
resource "google_service_account" "cloudrun" {
  account_id   = "${var.service_name}-run"
  display_name = "Cloud Run SA — ${var.service_name}"
}

# Allow the load balancer (and any caller reaching Cloud Run via the LB) to
# invoke the production service without bearer tokens.
# Direct-internet access is still blocked by the INTERNAL_LOAD_BALANCER ingress setting.
resource "google_cloud_run_v2_service_iam_member" "prod_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Allow authenticated callers to reach the staging service (Google account required)
resource "google_cloud_run_v2_service_iam_member" "staging_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.staging.name
  role     = "roles/run.invoker"
  member   = "allAuthenticatedUsers"
}

# ---------------------------------------------------------------------------
# Cloud Build service account
# ---------------------------------------------------------------------------
resource "google_service_account" "cloudbuild" {
  account_id   = "${var.service_name}-build"
  display_name = "Cloud Build SA — ${var.service_name}"
}

resource "google_project_iam_member" "cloudbuild_builder" {
  project = var.project_id
  role    = "roles/cloudbuild.builds.builder"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_project_iam_member" "cloudbuild_ar_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_project_iam_member" "cloudbuild_deploy_releaser" {
  project = var.project_id
  role    = "roles/clouddeploy.releaser"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_project_iam_member" "cloudbuild_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

# ---------------------------------------------------------------------------
# Cloud Deploy service account
# ---------------------------------------------------------------------------
resource "google_service_account" "clouddeploy" {
  account_id   = "${var.service_name}-deploy"
  display_name = "Cloud Deploy SA — ${var.service_name}"
}

resource "google_project_iam_member" "clouddeploy_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.clouddeploy.email}"
}

# Cloud Deploy needs to act as the Cloud Run SA when deploying
resource "google_service_account_iam_member" "clouddeploy_act_as_cloudrun" {
  service_account_id = google_service_account.cloudrun.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.clouddeploy.email}"
}

resource "google_project_iam_member" "clouddeploy_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.clouddeploy.email}"
}
