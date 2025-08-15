# Cloud KMSキーリング
resource "google_kms_key_ring" "cloudsql_keyring" {
  name     = "cloudsql-${var.environment}-keyring"
  location = var.region
}

# 暗号化キー
resource "google_kms_crypto_key" "cloudsql_key" {
  name     = "cloudsql-${var.environment}-key"
  key_ring = google_kms_key_ring.cloudsql_keyring.id
  purpose  = "ENCRYPT_DECRYPT"

  version_template {
    algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Cloud SQLサービスアカウントへの権限付与
resource "google_kms_crypto_key_iam_binding" "cloudsql_crypto_key" {
  crypto_key_id = google_kms_crypto_key.cloudsql_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:service-${data.google_project.current.number}@gcp-sa-cloud-sql.iam.gserviceaccount.com",
  ]
}