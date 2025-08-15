output "instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.ha_instance.name
}

output "instance_connection_name" {
  description = "Cloud SQL instance connection name for Cloud SQL Proxy"
  value       = google_sql_database_instance.ha_instance.connection_name
}

output "private_ip_address" {
  description = "Private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.ha_instance.private_ip_address
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

output "ssl_cert_common_name" {
  description = "SSL certificate common name"
  value       = google_sql_ssl_cert.client_cert.common_name
}

output "ssl_cert_sha1_fingerprint" {
  description = "SSL certificate SHA1 fingerprint"
  value       = google_sql_ssl_cert.client_cert.sha1_fingerprint
}

output "app_service_account_email" {
  description = "Application service account email"
  value       = google_service_account.app_sa.email
}

output "vpc_network_name" {
  description = "VPC network name"
  value       = google_compute_network.cloudsql_vpc.name
}

output "subnet_name" {
  description = "Subnet name"
  value       = google_compute_subnetwork.cloudsql_subnet.name
}

output "kms_key_id" {
  description = "KMS key ID used for encryption"
  value       = google_kms_crypto_key.cloudsql_key.id
}