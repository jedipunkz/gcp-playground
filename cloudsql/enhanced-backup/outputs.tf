output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.enhanced_backup_instance.name
}

output "instance_connection_name" {
  description = "Cloud SQL instance connection name"
  value       = google_sql_database_instance.enhanced_backup_instance.connection_name
}

output "private_ip_address" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.enhanced_backup_instance.private_ip_address
}

output "database_name" {
  description = "Database name"
  value       = google_sql_database.database.name
}

output "app_service_account_email" {
  description = "Application service account email"
  value       = google_service_account.app_sa.email
}

output "vpc_network_name" {
  description = "VPC network name"
  value       = google_compute_network.cloudsql_vpc.name
}

output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = google_kms_crypto_key.cloudsql_key.id
}