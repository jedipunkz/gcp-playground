# Cloud SQL管理用サービスアカウント
resource "google_service_account" "cloudsql_sa" {
  account_id   = "cloudsql-${var.environment}-admin"
  display_name = "Cloud SQL Admin Service Account (${var.environment})"
  description  = "Service account for Cloud SQL administration in ${var.environment}"
}

# アプリケーション用サービスアカウント
resource "google_service_account" "app_sa" {
  account_id   = "cloudsql-${var.environment}-app"
  display_name = "Cloud SQL Application Service Account (${var.environment})"
  description  = "Service account for application database access in ${var.environment}"
}

# Cloud SQL管理権限
resource "google_project_iam_member" "cloudsql_admin" {
  project = var.project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${google_service_account.cloudsql_sa.email}"
}

# アプリケーション用データベース接続権限
resource "google_project_iam_member" "cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

# Cloud SQL Proxyを使用するためのインスタンス権限
resource "google_project_iam_member" "cloudsql_instance_user" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.app_sa.email}"
}

# KMSキーへのアクセス権限
resource "google_kms_crypto_key_iam_member" "app_kms_access" {
  crypto_key_id = google_kms_crypto_key.cloudsql_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.app_sa.email}"
}