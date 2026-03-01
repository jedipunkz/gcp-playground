# VPC network dedicated to Cloud Run Jobs
resource "google_compute_network" "vpc" {
  name                    = "${var.job_name}-jobs-vpc"
  auto_create_subnetworks = false
}

# Subnet in the job region
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.job_name}-jobs-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# VPC Serverless Connector — lets job tasks reach private VPC resources
# (Cloud SQL, Redis, internal APIs, etc.)
resource "google_vpc_access_connector" "connector" {
  name          = "${var.job_name}-jobs-conn"
  region        = var.region
  ip_cidr_range = "10.8.0.0/28"
  network       = google_compute_network.vpc.name
  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3
}
