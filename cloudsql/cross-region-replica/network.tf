# Primary region VPC
resource "google_compute_network" "primary_vpc" {
  name                    = "cloudsql-${var.environment}-primary-vpc"
  auto_create_subnetworks = false
  routing_mode           = "REGIONAL"
}

resource "google_compute_subnetwork" "primary_subnet" {
  name          = "cloudsql-${var.environment}-primary-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.primary_region
  network       = google_compute_network.primary_vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# Primary region private service connection
resource "google_compute_global_address" "primary_private_ip" {
  name          = "cloudsql-${var.environment}-primary-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.primary_vpc.id
}

resource "google_service_networking_connection" "primary_private_vpc_connection" {
  network                 = google_compute_network.primary_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.primary_private_ip.name]
}

# DR region VPC
resource "google_compute_network" "dr_vpc" {
  name                    = "cloudsql-${var.environment}-dr-vpc"
  auto_create_subnetworks = false
  routing_mode           = "REGIONAL"
}

resource "google_compute_subnetwork" "dr_subnet" {
  name          = "cloudsql-${var.environment}-dr-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.dr_region
  network       = google_compute_network.dr_vpc.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.11.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.12.0.0/16"
  }
}

# DR region private service connection
resource "google_compute_global_address" "dr_private_ip" {
  name          = "cloudsql-${var.environment}-dr-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.dr_vpc.id
}

resource "google_service_networking_connection" "dr_private_vpc_connection" {
  network                 = google_compute_network.dr_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.dr_private_ip.name]
}

# Firewall rules
resource "google_compute_firewall" "primary_cloudsql_proxy" {
  name    = "cloudsql-${var.environment}-primary-proxy"
  network = google_compute_network.primary_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3307"]
  }

  source_ranges = ["10.0.0.0/16"]
  target_tags   = ["cloudsql-proxy"]
}

resource "google_compute_firewall" "dr_cloudsql_proxy" {
  name    = "cloudsql-${var.environment}-dr-proxy"
  network = google_compute_network.dr_vpc.name

  allow {
    protocol = "tcp"
    ports    = ["3307"]
  }

  source_ranges = ["10.10.0.0/16"]
  target_tags   = ["cloudsql-proxy"]
}