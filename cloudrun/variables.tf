variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "asia-northeast1"
}

variable "service_name" {
  description = "The name of the Cloud Run service (used as a prefix for related resources)"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Custom domain name for the HTTPS load balancer (e.g. app.example.com)"
  type        = string
  default     = "app.gcp-playground.example.com"
}

variable "min_instances" {
  description = "Minimum number of Cloud Run instances"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances"
  type        = number
  default     = 10
}

variable "cpu_limit" {
  description = "CPU limit for each Cloud Run instance"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit for each Cloud Run instance"
  type        = string
  default     = "512Mi"
}

variable "github_owner" {
  description = "GitHub repository owner (user or org)"
  type        = string
  default     = "jedipunkz"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "gcp-playground"
}

variable "github_branch" {
  description = "GitHub branch to trigger Cloud Build on push"
  type        = string
  default     = "main"
}

variable "cloud_armor_rate_limit_count" {
  description = "Max requests per interval before rate limiting kicks in"
  type        = number
  default     = 100
}

variable "cloud_armor_rate_limit_interval_sec" {
  description = "Interval in seconds for rate limiting window"
  type        = number
  default     = 60
}
