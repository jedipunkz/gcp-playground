variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "asia-northeast1"
}

variable "job_name" {
  description = "Base name for job resources (used as a prefix)"
  type        = string
  default     = "myjob"
}

# ---------------------------------------------------------------------------
# Pattern 1: Scheduled Batch ETL
# ---------------------------------------------------------------------------

variable "batch_schedule" {
  description = "Cron schedule for the batch ETL job (Cloud Scheduler syntax)"
  type        = string
  default     = "0 2 * * *" # 02:00 daily
}

variable "batch_schedule_timezone" {
  description = "IANA timezone for Cloud Scheduler"
  type        = string
  default     = "Asia/Tokyo"
}

# ---------------------------------------------------------------------------
# Pattern 2: Parallel Fan-out
# ---------------------------------------------------------------------------

variable "parallel_task_count" {
  description = "Total number of independent task shards in the parallel job"
  type        = number
  default     = 10
}

variable "parallel_parallelism" {
  description = "Number of tasks allowed to run concurrently (0 = all at once)"
  type        = number
  default     = 5
}

# ---------------------------------------------------------------------------
# Resource sizing (shared across all jobs)
# ---------------------------------------------------------------------------

variable "cpu_limit" {
  description = "CPU limit per task container"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit per task container"
  type        = string
  default     = "512Mi"
}
