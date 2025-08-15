# Cloud SQL管理用サービスアカウント
resource "google_service_account" "cloudsql_sa" {
  account_id   = "cloudsql-${var.environment}-admin"
  display_name = "Cloud SQL Admin Service Account (${var.environment})"
  description  = "Service account for Cloud SQL administration in ${var.environment}"
}

# Primary region アプリケーション用サービスアカウント
resource "google_service_account" "primary_app_sa" {
  account_id   = "cloudsql-${var.environment}-primary-app"
  display_name = "Cloud SQL Primary App Service Account (${var.environment})"
  description  = "Service account for primary region database access in ${var.environment}"
}

# DR region アプリケーション用サービスアカウント
resource "google_service_account" "dr_app_sa" {
  account_id   = "cloudsql-${var.environment}-dr-app"
  display_name = "Cloud SQL DR App Service Account (${var.environment})"
  description  = "Service account for DR region database access in ${var.environment}"
}

# Cloud SQL管理権限
resource "google_project_iam_member" "cloudsql_admin" {
  project = var.project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${google_service_account.cloudsql_sa.email}"
}

# Primary アプリケーション用権限
resource "google_project_iam_member" "primary_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.primary_app_sa.email}"
}

resource "google_project_iam_member" "primary_cloudsql_instance_user" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.primary_app_sa.email}"
}

# DR アプリケーション用権限
resource "google_project_iam_member" "dr_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.dr_app_sa.email}"
}

resource "google_project_iam_member" "dr_cloudsql_instance_user" {
  project = var.project_id
  role    = "roles/cloudsql.instanceUser"
  member  = "serviceAccount:${google_service_account.dr_app_sa.email}"
}

# KMSキーへのアクセス権限
resource "google_kms_crypto_key_iam_member" "primary_app_kms_access" {
  crypto_key_id = google_kms_crypto_key.primary_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.primary_app_sa.email}"
}

resource "google_kms_crypto_key_iam_member" "dr_app_kms_access" {
  crypto_key_id = google_kms_crypto_key.dr_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.dr_app_sa.email}"
}