# ---------------------------------------------------------------------------
# Cloud Deploy — delivery pipeline & targets
# ---------------------------------------------------------------------------

# Delivery pipeline: staging → prod (prod requires manual approval)
resource "google_clouddeploy_delivery_pipeline" "app" {
  name     = "${var.service_name}-pipeline"
  location = var.region

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.staging.name
      profiles  = ["staging"]
    }

    stages {
      target_id = google_clouddeploy_target.prod.name
      profiles  = ["prod"]
    }
  }
}

# Staging target — no approval required
resource "google_clouddeploy_target" "staging" {
  name     = "${var.service_name}-staging"
  location = var.region

  run {
    location = "projects/${var.project_id}/locations/${var.region}"
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy.email
  }
}

# Production target — requires manual approval before promotion
resource "google_clouddeploy_target" "prod" {
  name             = "${var.service_name}-prod"
  location         = var.region
  require_approval = true

  run {
    location = "projects/${var.project_id}/locations/${var.region}"
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy.email
  }
}

# ---------------------------------------------------------------------------
# Cloud Build — trigger on push to the configured branch
# ---------------------------------------------------------------------------
# Prerequisites:
#   Connect your GitHub repository to Cloud Build in the GCP Console
#   (Cloud Build → Triggers → Connect repository) before applying.
resource "google_cloudbuild_trigger" "app" {
  name            = "${var.service_name}-trigger"
  location        = var.region
  service_account = google_service_account.cloudbuild.id

  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^${var.github_branch}$"
    }
  }

  filename = "cloudbuild.yaml"

  substitutions = {
    _REGION        = var.region
    _REPO_URL      = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}"
    _SERVICE_NAME  = var.service_name
    _PIPELINE_NAME = google_clouddeploy_delivery_pipeline.app.name
  }
}
