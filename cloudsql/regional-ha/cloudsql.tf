# Cloud SQL インスタンス (Regional HA)
resource "google_sql_database_instance" "ha_instance" {
  name             = "mysql-${var.environment}-ha-instance"
  database_version = "MYSQL_8_0"
  region          = var.region
  
  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier                        = var.instance_tier
    availability_type          = "REGIONAL"  # HA構成を有効化
    disk_type                  = "PD_SSD"
    disk_size                  = var.disk_size
    disk_autoresize           = true
    disk_autoresize_limit     = 500
    
    # CMEK暗号化は現在beta版のため、簡略化
    # encryption_key_name = google_kms_crypto_key.cloudsql_key.id
    
    backup_configuration {
      enabled                        = true
      start_time                    = var.backup_start_time
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      location                      = var.region
      
      backup_retention_settings {
        retained_backups = 30
        retention_unit   = "COUNT"
      }
    }
    
    # VPCプライベート接続のみ
    ip_configuration {
      ipv4_enabled       = false  # パブリックIPを無効化
      private_network    = google_compute_network.cloudsql_vpc.id
      require_ssl        = true
      
      # SSL証明書の設定
      ssl_mode = "ENCRYPTED_ONLY"
    }
    
    # データベースフラグ（セキュリティ強化）
    database_flags {
      name  = "slow_query_log"
      value = "on"
    }
    
    database_flags {
      name  = "log_bin_trust_function_creators"
      value = "off"
    }
    
    database_flags {
      name  = "local_infile"
      value = "off"
    }
    
    # メンテナンスウィンドウ
    maintenance_window {
      day          = var.maintenance_day
      hour         = var.maintenance_hour
      update_track = "stable"
    }
    
    # インサイト設定
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = true
    }
  }

  deletion_protection = true
}

# SSL証明書
resource "google_sql_ssl_cert" "client_cert" {
  common_name = "mysql-${var.environment}-client-cert"
  instance    = google_sql_database_instance.ha_instance.name
}

# データベース
resource "google_sql_database" "database" {
  name     = var.db_name
  instance = google_sql_database_instance.ha_instance.name
  charset  = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

# データベースユーザー（IAM認証）
resource "google_sql_user" "iam_user" {
  name     = google_service_account.app_sa.email
  instance = google_sql_database_instance.ha_instance.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

# 従来認証のユーザー（必要な場合）
resource "google_sql_user" "mysql_user" {
  name     = var.db_user
  instance = google_sql_database_instance.ha_instance.name
  password = var.db_password
  
}