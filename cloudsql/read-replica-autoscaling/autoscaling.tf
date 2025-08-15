# Cloud Functions用のサービスアカウント
resource "google_service_account" "autoscaling_sa" {
  account_id   = "cloudsql-autoscaling-${var.environment}"
  display_name = "Cloud SQL Autoscaling Service Account"
  description  = "Service account for Cloud SQL autoscaling functions"
}

# Cloud SQL管理権限
resource "google_project_iam_member" "autoscaling_cloudsql_admin" {
  project = var.project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${google_service_account.autoscaling_sa.email}"
}

# Cloud Monitoring権限
resource "google_project_iam_member" "autoscaling_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.autoscaling_sa.email}"
}

# Cloud Storage bucket for function source
resource "google_storage_bucket" "function_source" {
  name     = "${var.project_id}-cloudsql-autoscaling-source"
  location = var.region

  uniform_bucket_level_access = true
  
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

# Cloud Storage object for function source
resource "google_storage_bucket_object" "function_source" {
  name   = "autoscaling-function-${timestamp()}.zip"
  bucket = google_storage_bucket.function_source.name
  source = data.archive_file.function_source.output_path
}

# Archive function source code
data "archive_file" "function_source" {
  type        = "zip"
  output_path = "/tmp/autoscaling-function.zip"
  source {
    content = templatefile("${path.module}/autoscaling_function.py", {
      project_id              = var.project_id
      region                  = var.region
      primary_instance_name   = google_sql_database_instance.primary.name
      min_replica_count      = var.min_replica_count
      max_replica_count      = var.max_replica_count
      cpu_threshold_high     = var.cpu_threshold_high
      cpu_threshold_low      = var.cpu_threshold_low
      connection_threshold_high = var.connection_threshold_high
    })
    filename = "main.py"
  }
  source {
    content = file("${path.module}/requirements.txt")
    filename = "requirements.txt"
  }
}

# Cloud Function for autoscaling
resource "google_cloudfunctions_function" "autoscaling_function" {
  name        = "cloudsql-autoscaling-${var.environment}"
  description = "Cloud SQL Read Replica Autoscaling Function"
  runtime     = "python39"
  region      = var.region

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.function_source.name
  source_archive_object = google_storage_bucket_object.function_source.name
  event_trigger {
    event_type = "providers/cloud.pubsub/eventTypes/topic.publish"
    resource   = google_pubsub_topic.autoscaling_topic.name
  }
  entry_point = "autoscale_replicas"
  
  service_account_email = google_service_account.autoscaling_sa.email
  
  environment_variables = {
    PROJECT_ID              = var.project_id
    REGION                  = var.region
    PRIMARY_INSTANCE_NAME   = google_sql_database_instance.primary.name
    MIN_REPLICA_COUNT      = var.min_replica_count
    MAX_REPLICA_COUNT      = var.max_replica_count
    CPU_THRESHOLD_HIGH     = var.cpu_threshold_high
    CPU_THRESHOLD_LOW      = var.cpu_threshold_low
    CONNECTION_THRESHOLD_HIGH = var.connection_threshold_high
  }
}

# Pub/Sub topic for autoscaling triggers
resource "google_pubsub_topic" "autoscaling_topic" {
  name = "cloudsql-autoscaling-${var.environment}"
}

# Cloud Scheduler job for periodic autoscaling checks
resource "google_cloud_scheduler_job" "autoscaling_job" {
  name        = "cloudsql-autoscaling-${var.environment}"
  description = "Periodic Cloud SQL autoscaling check"
  schedule    = "*/5 * * * *"  # Every 5 minutes
  time_zone   = "Asia/Tokyo"
  region      = var.region

  pubsub_target {
    topic_name = google_pubsub_topic.autoscaling_topic.id
    data       = base64encode("{\"action\": \"check_and_scale\"}")
  }
}

# Cloud Monitoring alert policy for high CPU
resource "google_monitoring_alert_policy" "high_cpu_alert" {
  display_name = "Cloud SQL High CPU - ${var.environment}"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Cloud SQL CPU utilization"
    condition_threshold {
      filter          = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = var.cpu_threshold_high / 100

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = []

  alert_strategy {
    auto_close = "1800s"
  }
}

# Cloud Monitoring alert policy for high connections
resource "google_monitoring_alert_policy" "high_connections_alert" {
  display_name = "Cloud SQL High Connections - ${var.environment}"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Cloud SQL connection count"
    condition_threshold {
      filter          = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/network/connections\""
      duration        = "300s"
      comparison      = "COMPARISON_GREATER_THAN"
      threshold_value = var.connection_threshold_high

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = []

  alert_strategy {
    auto_close = "1800s"
  }
}