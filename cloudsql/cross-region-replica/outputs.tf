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

output "replica_instance_name" {
  description = "Cross-region replica instance name"
  value       = google_sql_database_instance.cross_region_replica.name
}

output "replica_connection_name" {
  description = "Cross-region replica connection name"
  value       = google_sql_database_instance.cross_region_replica.connection_name
}

output "replica_private_ip" {
  description = "Cross-region replica private IP address"
  value       = google_sql_database_instance.cross_region_replica.private_ip_address
}

output "database_name" {
  description = "Database name"
  value       = google_sql_database.database.name
}

output "primary_iam_user_email" {
  description = "Primary IAM service account email"
  value       = google_sql_user.primary_iam_user.name
}

output "dr_iam_user_email" {
  description = "DR IAM service account email"
  value       = google_sql_user.dr_iam_user.name
}

output "primary_mysql_user_name" {
  description = "Primary MySQL user name"
  value       = google_sql_user.primary_mysql_user.name
  sensitive   = true
}

output "primary_app_service_account_email" {
  description = "Primary application service account email"
  value       = google_service_account.primary_app_sa.email
}

output "dr_app_service_account_email" {
  description = "DR application service account email"
  value       = google_service_account.dr_app_sa.email
}

output "primary_vpc_network_name" {
  description = "Primary VPC network name"
  value       = google_compute_network.primary_vpc.name
}

output "dr_vpc_network_name" {
  description = "DR VPC network name"
  value       = google_compute_network.dr_vpc.name
}

output "primary_kms_key_id" {
  description = "Primary KMS key ID used for encryption"
  value       = google_kms_crypto_key.primary_key.id
}

output "dr_kms_key_id" {
  description = "DR KMS key ID used for encryption"
  value       = google_kms_crypto_key.dr_key.id
}