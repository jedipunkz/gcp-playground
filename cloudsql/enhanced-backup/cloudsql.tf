# VPCネットワーク
resource "google_compute_network" "cloudsql_vpc" {
  name                    = "cloudsql-${var.environment}-vpc"
  auto_create_subnetworks = false
  routing_mode           = "REGIONAL"
}

resource "google_compute_subnetwork" "cloudsql_subnet" {
  name          = "cloudsql-${var.environment}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.cloudsql_vpc.id
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

# KMS設定
resource "google_kms_key_ring" "cloudsql_keyring" {
  name     = "cloudsql-${var.environment}-keyring"
  location = var.region
}

resource "google_kms_crypto_key" "cloudsql_key" {
  name     = "cloudsql-${var.environment}-key"
  key_ring = google_kms_key_ring.cloudsql_keyring.id
  purpose  = "ENCRYPT_DECRYPT"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key_iam_binding" "cloudsql_crypto_key" {
  crypto_key_id = google_kms_crypto_key.cloudsql_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:service-${data.google_project.current.number}@gcp-sa-cloud-sql.iam.gserviceaccount.com",
  ]
}

# サービスアカウント
resource "google_service_account" "app_sa" {
  account_id   = "cloudsql-${var.environment}-app"
  display_name = "Cloud SQL Application Service Account"
}

resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

# Cloud SQL インスタンス (Enhanced Backup対応)
resource "google_sql_database_instance" "enhanced_backup_instance" {
  name             = "mysql-${var.environment}-enhanced-backup"
  database_version = "MYSQL_8_0"
  region          = var.region
  
  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = var.instance_tier
    availability_type = "REGIONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size
    disk_autoresize   = true
    
    # encryption_key_name = google_kms_crypto_key.cloudsql_key.id
    
    backup_configuration {
      enabled                        = true
      start_time                    = var.backup_start_time
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 35
      location                      = var.region
      
      backup_retention_settings {
        retained_backups = 15
        retention_unit   = "COUNT"
      }
    }
    
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.cloudsql_vpc.id
      require_ssl     = true
      ssl_mode        = "ENCRYPTED_ONLY"
    }
    
    database_flags {
      name  = "slow_query_log"
      value = "on"
    }
    
    database_flags {
      name  = "local_infile"
      value = "off"
    }
    
    insights_config {
      query_insights_enabled = true
    }
    
    maintenance_window {
      day          = var.maintenance_day
      hour         = var.maintenance_hour
      update_track = "stable"
    }
  }

  deletion_protection = true
}

# データベース
resource "google_sql_database" "database" {
  name     = var.db_name
  instance = google_sql_database_instance.enhanced_backup_instance.name
  charset  = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

# データベースユーザー
resource "google_sql_user" "iam_user" {
  name     = google_service_account.app_sa.email
  instance = google_sql_database_instance.enhanced_backup_instance.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

resource "google_sql_user" "mysql_user" {
  name     = var.db_user
  instance = google_sql_database_instance.enhanced_backup_instance.name
  password = var.db_password
  
}