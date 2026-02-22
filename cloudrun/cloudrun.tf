locals {
  # Artifact Registry image URL prefix
  image_prefix = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repo.repository_id}/${var.service_name}"
}

# Production Cloud Run service
# ingress is restricted to the global load balancer only.
# Cloud Deploy manages subsequent image updates; Terraform owns all other config.
resource "google_cloud_run_v2_service" "app" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = google_service_account.cloudrun.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      # Placeholder image; replaced by Cloud Deploy on first release
      image = "${local.image_prefix}:latest"

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        cpu_idle = true
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }
    }
  }

  lifecycle {
    # Cloud Deploy manages the container image; prevent Terraform from reverting it
    ignore_changes = [template[0].containers[0].image]
  }

  depends_on = [google_vpc_access_connector.connector]
}

# Staging Cloud Run service (no LB; direct Cloud Run URL for pre-prod validation)
resource "google_cloud_run_v2_service" "staging" {
  name     = "${var.service_name}-staging"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    service_account = google_service_account.cloudrun.email

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }

    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }

    containers {
      image = "${local.image_prefix}:latest"

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        cpu_idle = true
      }

      env {
        name  = "ENVIRONMENT"
        value = "staging"
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].containers[0].image]
  }

  depends_on = [google_vpc_access_connector.connector]
}
