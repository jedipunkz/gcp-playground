output "primary_instance_name" {
  description = "Primary Cloud SQL instance name"
  value       = google_sql_database_instance.primary.name
}

output "primary_connection_name" {
  description = "Primary Cloud SQL instance connection name"
  value       = google_sql_database_instance.primary.connection_name
}

output "primary_private_ip" {
  description = "Primary instance private IP address"
  value       = google_sql_database_instance.primary.private_ip_address
}

output "replica_instance_names" {
  description = "Read replica instance names"
  value       = google_sql_database_instance.read_replica[*].name
}

output "replica_connection_names" {
  description = "Read replica connection names"
  value       = google_sql_database_instance.read_replica[*].connection_name
}

output "replica_private_ips" {
  description = "Read replica private IP addresses"
  value       = google_sql_database_instance.read_replica[*].private_ip_address
}

output "database_name" {
  description = "Database name"
  value       = google_sql_database.database.name
}

output "iam_user_email" {
  description = "IAM service account email for database access"
  value       = google_sql_user.iam_user.name
}

output "mysql_user_name" {
  description = "MySQL user name"
  value       = google_sql_user.mysql_user.name
  sensitive   = true
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