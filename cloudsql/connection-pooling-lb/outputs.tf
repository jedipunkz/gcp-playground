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

output "read_load_balancer_ip" {
  description = "Internal load balancer IP for read traffic"
  value       = google_compute_address.read_lb_ip.address
}

output "write_load_balancer_ip" {
  description = "Internal load balancer IP for write traffic"
  value       = google_compute_address.write_lb_ip.address
}

output "pgbouncer_service_account_email" {
  description = "PgBouncer service account email"
  value       = google_service_account.pgbouncer_sa.email
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

output "connection_instructions" {
  description = "Connection instructions for applications"
  value = <<-EOT
    # For write operations (INSERT, UPDATE, DELETE):
    Connect to: ${google_compute_address.write_lb_ip.address}:6432
    Database: ${var.db_name}_write
    
    # For read operations (SELECT):
    Connect to: ${google_compute_address.read_lb_ip.address}:6432
    Database: ${var.db_name}_read
    
    # Username: ${var.db_user}
    # Password: [use the configured password]
    
    # Connection pooling is handled automatically by PgBouncer
    EOT
}