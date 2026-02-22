# VPC network dedicated to this service
resource "google_compute_network" "vpc" {
  name                    = "${var.service_name}-vpc"
  auto_create_subnetworks = false
}

# Subnet for VPC Serverless Connector
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.service_name}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# VPC Serverless Connector allows Cloud Run to reach VPC resources (e.g. Cloud SQL, Redis)
resource "google_vpc_access_connector" "connector" {
  name          = "${var.service_name}-connector"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.name
  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3
}
