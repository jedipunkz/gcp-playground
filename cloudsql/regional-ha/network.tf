# VPCネットワーク
resource "google_compute_network" "cloudsql_vpc" {
  name                    = "cloudsql-${var.environment}-vpc"
  auto_create_subnetworks = false
  routing_mode           = "REGIONAL"
}

# サブネット
resource "google_compute_subnetwork" "cloudsql_subnet" {
  name          = "cloudsql-${var.environment}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.cloudsql_vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# プライベートサービス接続
resource "google_compute_global_address" "private_ip_address" {
  name          = "cloudsql-${var.environment}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.cloudsql_vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.cloudsql_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# ファイアウォールルール - Cloud SQL Proxy用
resource "google_compute_firewall" "cloudsql_proxy" {
  name    = "cloudsql-${var.environment}-proxy"
  network = google_compute_network.cloudsql_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3307"]
  }

  source_ranges = ["10.0.0.0/16"]
  target_tags   = ["cloudsql-proxy"]
}