# Cloud SQL プライマリインスタンス
resource "google_sql_database_instance" "primary" {
  name             = "mysql-${var.environment}-primary"
  database_version = "MYSQL_8_0"
  region          = var.region
  
  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = var.primary_instance_tier
    availability_type = "REGIONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size
    disk_autoresize   = true
    disk_autoresize_limit = 500
    
    backup_configuration {
      enabled            = true
      binary_log_enabled = true  # レプリカ作成に必要
      start_time        = var.backup_start_time
      location          = var.region
      
      backup_retention_settings {
        retained_backups = 30
        retention_unit   = "COUNT"
      }
    }
    
    # VPCプライベート接続のみ
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.cloudsql_vpc.id
      require_ssl     = true
      ssl_mode        = "ENCRYPTED_ONLY"
    }
    
    # セキュリティ強化フラグ
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
    
    # メンテナンスウィンドウ
    maintenance_window {
      day          = var.maintenance_day
      hour         = var.maintenance_hour
      update_track = "stable"
    }
  }

  deletion_protection = true
}

# 初期 Read Replica インスタンス
resource "google_sql_database_instance" "read_replica" {
  count            = var.initial_replica_count
  name             = "mysql-${var.environment}-read-replica-${count.index + 1}"
  database_version = "MYSQL_8_0"
  region          = var.region
  
  master_instance_name = google_sql_database_instance.primary.name
  
  replica_configuration {
    failover_target = false
  }

  settings {
    tier = var.replica_tier
    
    # VPCプライベート接続
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.cloudsql_vpc.id
      require_ssl     = true
      ssl_mode        = "ENCRYPTED_ONLY"
    }
    
    insights_config {
      query_insights_enabled = true
    }
  }

  deletion_protection = true
}

# SSL証明書
resource "google_sql_ssl_cert" "client_cert" {
  common_name = "mysql-${var.environment}-client-cert"
  instance    = google_sql_database_instance.primary.name
}

# データベース
resource "google_sql_database" "database" {
  name     = var.db_name
  instance = google_sql_database_instance.primary.name
  charset  = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

# データベースユーザー（IAM認証）
resource "google_sql_user" "iam_user" {
  name     = google_service_account.app_sa.email
  instance = google_sql_database_instance.primary.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

# 従来認証のユーザー
resource "google_sql_user" "mysql_user" {
  name     = var.db_user
  instance = google_sql_database_instance.primary.name
  password = var.db_password
}