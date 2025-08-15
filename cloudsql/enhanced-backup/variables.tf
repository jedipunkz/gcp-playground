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

variable "instance_tier" {
  description = "Cloud SQL instance tier"
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
  default     = "02:00"
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

variable "backup_retention_days" {
  description = "Standard backup retention days"
  type        = number
  default     = 30
}

variable "weekly_backup_retention_days" {
  description = "Weekly backup retention days"
  type        = number
  default     = 90
}