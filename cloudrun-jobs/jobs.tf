locals {
  image_prefix = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.jobs.repository_id}"
}

# ---------------------------------------------------------------------------
# Pattern 1: Scheduled Batch ETL
#
# Use case: Nightly data pipeline, DB migration, report generation
# Trigger:  Cloud Scheduler → Cloud Run Admin API (see scheduler.tf)
# Design:
#   - Single task (task_count=1, parallelism=1)
#   - Long timeout (1 hour) for heavy processing
#   - Retries limited to 2 — ETL should be idempotent
#   - Secrets from Secret Manager (no plaintext credentials in env vars)
#   - VPC connector to reach private Cloud SQL / Redis
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_job" "batch_etl" {
  name     = "${var.job_name}-batch-etl"
  location = var.region

  labels = {
    pattern     = "scheduled"
    managed-by  = "terraform"
  }

  template {
    task_count  = 1
    parallelism = 1

    template {
      timeout     = "3600s" # 1 hour max; tune down once you know typical runtime
      max_retries = 2

      service_account = google_service_account.batch_etl.email

      containers {
        image = "${local.image_prefix}/batch-etl:latest"

        env {
          name  = "ENVIRONMENT"
          value = "prod"
        }

        # Best practice: pull secrets from Secret Manager instead of hardcoding
        # The SA (batch_etl) has roles/secretmanager.secretAccessor
        env {
          name = "DB_PASSWORD"
          value_source {
            secret_key_ref {
              secret  = google_secret_manager_secret.db_password.secret_id
              version = "latest"
            }
          }
        }

        resources {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
        }
      }

      # Route egress through VPC to reach private Cloud SQL, Redis, etc.
      vpc_access {
        connector = google_vpc_access_connector.connector.id
        egress    = "PRIVATE_RANGES_ONLY"
      }
    }
  }
}

# DB password placeholder — populate the actual value via:
#   gcloud secrets versions add <secret-id> --data-file=<file>
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.job_name}-db-password"

  replication {
    auto {}
  }
}

# ---------------------------------------------------------------------------
# Pattern 2: Parallel Fan-out
#
# Use case: Large dataset processing, image resizing, shard-based ETL
# Trigger:  Manual (gcloud / API) or external orchestrator
# Design:
#   - task_count shards, up to parallelism running at once
#   - Each task reads CLOUD_RUN_TASK_INDEX (0-based) to determine its shard
#   - CLOUD_RUN_TASK_COUNT is also injected for dynamic sharding logic
#   - Short timeout per task (10 min) — keep tasks small and idempotent
#   - max_retries=3: safe to retry because tasks are idempotent
#   - No VPC needed when tasks only access GCS / public endpoints
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_job" "parallel" {
  name     = "${var.job_name}-parallel"
  location = var.region

  labels = {
    pattern    = "parallel"
    managed-by = "terraform"
  }

  template {
    task_count  = var.parallel_task_count
    parallelism = var.parallel_parallelism

    template {
      timeout     = "600s" # 10 min per shard
      max_retries = 3      # safe to retry idempotent shards

      service_account = google_service_account.parallel.email

      containers {
        image = "${local.image_prefix}/parallel-worker:latest"

        env {
          name  = "TOTAL_TASKS"
          value = tostring(var.parallel_task_count)
        }

        # Cloud Run automatically injects:
        #   CLOUD_RUN_TASK_INDEX  — 0-based index of this task
        #   CLOUD_RUN_TASK_COUNT  — total number of tasks
        #   CLOUD_RUN_TASK_ATTEMPT — retry attempt number (0 = first run)
        # Your application reads these to determine which shard to process.

        resources {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Pattern 3: Event-driven
#
# Use case: Process a file immediately after it lands in GCS
# Trigger:  GCS object-finalized → Eventarc → Cloud Run Job (see eventarc.tf)
# Design:
#   - Single task triggered per event
#   - 15-minute timeout — event payloads should be small and fast to process
#   - max_retries=1: Eventarc delivers at-least-once; keep handler idempotent
#   - INPUT_BUCKET injected so the container knows where to read from
#   - Eventarc also injects CloudEvents headers (ce-*) for the specific object
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_job" "event_processor" {
  name     = "${var.job_name}-event-processor"
  location = var.region

  labels = {
    pattern    = "event-driven"
    managed-by = "terraform"
  }

  template {
    task_count  = 1
    parallelism = 1

    template {
      timeout     = "900s" # 15 min
      max_retries = 1      # retry once; handler must be idempotent

      service_account = google_service_account.event_processor.email

      containers {
        image = "${local.image_prefix}/event-processor:latest"

        env {
          name  = "INPUT_BUCKET"
          value = google_storage_bucket.input.name
        }

        resources {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
        }
      }
    }
  }
}
