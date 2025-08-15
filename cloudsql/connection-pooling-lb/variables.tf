variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "asia-northeast1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "myapp"
}

variable "db_user" {
  description = "Database user name"
  type        = string
  default     = "myapp"
}

variable "db_password" {
  description = "Database user password"
  type        = string
  sensitive   = true
}

variable "pgbouncer_password" {
  description = "PgBouncer user password"
  type        = string
  sensitive   = true
}

variable "primary_instance_tier" {
  description = "Cloud SQL primary instance tier"
  type        = string
  default     = "db-n1-standard-2"
}

variable "replica_tier" {
  description = "Cloud SQL replica instance tier"
  type        = string
  default     = "db-n1-standard-1"
}

variable "replica_count" {
  description = "Number of read replicas to create"
  type        = number
  default     = 3
}

variable "disk_size" {
  description = "Disk size in GB"
  type        = number
  default     = 100
}

variable "backup_start_time" {
  description = "Backup start time (HH:MM format)"
  type        = string
  default     = "23:00"
}

variable "maintenance_day" {
  description = "Maintenance window day (1=Monday, 7=Sunday)"
  type        = number
  default     = 7
}

variable "maintenance_hour" {
  description = "Maintenance window hour (0-23)"
  type        = number
  default     = 4
}

variable "pgbouncer_instance_count" {
  description = "Number of PgBouncer instances"
  type        = number
  default     = 2
}

variable "machine_type" {
  description = "Machine type for PgBouncer instances"
  type        = string
  default     = "e2-medium"
}