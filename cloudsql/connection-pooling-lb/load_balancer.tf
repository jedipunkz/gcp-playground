# Instance Template for PgBouncer
resource "google_compute_instance_template" "pgbouncer_template" {
  name_prefix  = "pgbouncer-${var.environment}-"
  machine_type = var.machine_type
  region       = var.region

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
    disk_type    = "pd-standard"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.cloudsql_subnet.id
    # Internal IP only - no external IP
  }

  service_account {
    email  = google_service_account.pgbouncer_sa.email
    scopes = ["cloud-platform"]
  }

  metadata = {
    startup-script = templatefile("${path.module}/pgbouncer_startup.sh", {
      primary_ip = google_sql_database_instance.primary.private_ip_address
      replica_ips = join(",", google_sql_database_instance.read_replica[*].private_ip_address)
      db_name = var.db_name
      db_user = var.db_user
      db_password = var.db_password
      pgbouncer_password = var.pgbouncer_password
    })
  }

  tags = ["pgbouncer", "cloudsql-proxy"]

  lifecycle {
    create_before_destroy = true
  }
}

# Managed Instance Group for PgBouncer
resource "google_compute_region_instance_group_manager" "pgbouncer_group" {
  name   = "pgbouncer-${var.environment}-group"
  region = var.region

  base_instance_name = "pgbouncer-${var.environment}"
  target_size        = var.pgbouncer_instance_count

  version {
    instance_template = google_compute_instance_template.pgbouncer_template.id
  }

  named_port {
    name = "pgbouncer"
    port = 6432
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.pgbouncer_health.id
    initial_delay_sec = 300
  }
}

# Health Check for PgBouncer
resource "google_compute_health_check" "pgbouncer_health" {
  name = "pgbouncer-${var.environment}-health"

  timeout_sec        = 5
  check_interval_sec = 10
  healthy_threshold  = 2
  unhealthy_threshold = 3

  tcp_health_check {
    port = "6432"
  }
}

# Internal Load Balancer for Read Replicas
resource "google_compute_region_backend_service" "read_replica_backend" {
  name     = "read-replica-${var.environment}-backend"
  region   = var.region
  protocol = "TCP"

  backend {
    group = google_compute_region_instance_group_manager.pgbouncer_group.instance_group
  }

  health_checks = [google_compute_health_check.pgbouncer_health.id]

  connection_draining_timeout_sec = 300
}

# Forwarding Rule for Read Traffic
resource "google_compute_forwarding_rule" "read_replica_lb" {
  name   = "read-replica-${var.environment}-lb"
  region = var.region

  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.read_replica_backend.id
  
  ip_address = google_compute_address.read_lb_ip.address
  ports      = ["6432"]
  
  network    = google_compute_network.cloudsql_vpc.id
  subnetwork = google_compute_subnetwork.cloudsql_subnet.id
}

# Static IP for Read Load Balancer
resource "google_compute_address" "read_lb_ip" {
  name         = "read-replica-${var.environment}-lb-ip"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.cloudsql_subnet.id
}

# Forwarding Rule for Write Traffic (direct to primary)
resource "google_compute_forwarding_rule" "write_primary_lb" {
  name   = "write-primary-${var.environment}-lb"
  region = var.region

  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.write_primary_backend.id
  
  ip_address = google_compute_address.write_lb_ip.address
  ports      = ["6432"]
  
  network    = google_compute_network.cloudsql_vpc.id
  subnetwork = google_compute_subnetwork.cloudsql_subnet.id
}

# Backend Service for Write Traffic
resource "google_compute_region_backend_service" "write_primary_backend" {
  name     = "write-primary-${var.environment}-backend"
  region   = var.region
  protocol = "TCP"

  backend {
    group = google_compute_region_instance_group_manager.pgbouncer_group.instance_group
  }

  health_checks = [google_compute_health_check.pgbouncer_health.id]

  connection_draining_timeout_sec = 300
}

# Static IP for Write Load Balancer
resource "google_compute_address" "write_lb_ip" {
  name         = "write-primary-${var.environment}-lb-ip"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.cloudsql_subnet.id
}

# Service Account for PgBouncer instances
resource "google_service_account" "pgbouncer_sa" {
  account_id   = "pgbouncer-${var.environment}"
  display_name = "PgBouncer Service Account"
  description  = "Service account for PgBouncer connection pooling instances"
}

# Cloud SQL Client permissions for PgBouncer
resource "google_project_iam_member" "pgbouncer_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.pgbouncer_sa.email}"
}

# Firewall rule for PgBouncer
resource "google_compute_firewall" "pgbouncer_firewall" {
  name    = "pgbouncer-${var.environment}-firewall"
  network = google_compute_network.cloudsql_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["6432"]
  }

  source_ranges = [google_compute_subnetwork.cloudsql_subnet.ip_cidr_range]
  target_tags   = ["pgbouncer"]
}