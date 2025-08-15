variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "primary_region" {
  description = "The GCP region for primary resources"
  type        = string
  default     = "asia-northeast1"
}

variable "dr_region" {
  description = "The GCP region for DR resources"
  type        = string
  default     = "us-central1"
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

variable "primary_instance_tier" {
  description = "Cloud SQL primary instance tier"
  type        = string
  default     = "db-n1-standard-2"
}

variable "replica_instance_tier" {
  description = "Cloud SQL replica instance tier"
  type        = string
  default     = "db-n1-standard-2"
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