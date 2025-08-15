# Primary Cloud SQL インスタンス
resource "google_sql_database_instance" "primary" {
  name             = "mysql-${var.environment}-primary"
  database_version = "MYSQL_8_0"
  region          = var.primary_region
  
  depends_on = [google_service_networking_connection.primary_private_vpc_connection]

  settings {
    tier = var.primary_instance_tier
    availability_type = "REGIONAL"
    disk_type = "PD_SSD"
    disk_size = var.disk_size
    disk_autoresize = true
    disk_autoresize_limit = 500
    
    backup_configuration {
      enabled            = true
      binary_log_enabled = true
      start_time        = var.backup_start_time
      location          = var.primary_region
      
      backup_retention_settings {
        retained_backups = 30
        retention_unit   = "COUNT"
      }
    }
    
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.primary_vpc.id
      require_ssl     = true
      ssl_mode        = "ENCRYPTED_ONLY"
    }
    
    database_flags {
      name  = "local_infile"
      value = "off"
    }
    
    database_flags {
      name  = "skip_show_database"
      value = "on"
    }
    
    database_flags {
      name  = "slow_query_log"
      value = "on"
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

# Cross-Region Replica インスタンス
resource "google_sql_database_instance" "cross_region_replica" {
  name             = "mysql-${var.environment}-cross-region-replica"
  database_version = "MYSQL_8_0"
  region          = var.dr_region
  
  depends_on = [google_service_networking_connection.dr_private_vpc_connection]
  master_instance_name = google_sql_database_instance.primary.name
  
  replica_configuration {
    failover_target = false
  }

  settings {
    tier = var.replica_instance_tier
    
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.dr_vpc.id
      require_ssl     = true
      ssl_mode        = "ENCRYPTED_ONLY"
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
  instance = google_sql_database_instance.primary.name
  charset  = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

# Primary データベースユーザー（IAM認証）
resource "google_sql_user" "primary_iam_user" {
  name     = google_service_account.primary_app_sa.email
  instance = google_sql_database_instance.primary.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

# DR データベースユーザー（IAM認証）
resource "google_sql_user" "dr_iam_user" {
  name     = google_service_account.dr_app_sa.email
  instance = google_sql_database_instance.cross_region_replica.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

# Primary 従来認証ユーザー
resource "google_sql_user" "primary_mysql_user" {
  name     = var.db_user
  instance = google_sql_database_instance.primary.name
  password = var.db_password
  
}