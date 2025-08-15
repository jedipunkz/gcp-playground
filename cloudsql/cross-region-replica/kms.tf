# Primary region KMS
resource "google_kms_key_ring" "primary_keyring" {
  name     = "cloudsql-${var.environment}-primary-keyring"
  location = var.primary_region
}

resource "google_kms_crypto_key" "primary_key" {
  name     = "cloudsql-${var.environment}-primary-key"
  key_ring = google_kms_key_ring.primary_keyring.id
  purpose  = "ENCRYPT_DECRYPT"

  version_template {
    algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# DR region KMS
resource "google_kms_key_ring" "dr_keyring" {
  name     = "cloudsql-${var.environment}-dr-keyring"
  location = var.dr_region
}

resource "google_kms_crypto_key" "dr_key" {
  name     = "cloudsql-${var.environment}-dr-key"
  key_ring = google_kms_key_ring.dr_keyring.id
  purpose  = "ENCRYPT_DECRYPT"

  version_template {
    algorithm = "GOOGLE_SYMMETRIC_ENCRYPTION"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Cloud SQL service account permissions for primary region
resource "google_kms_crypto_key_iam_binding" "primary_cloudsql_crypto_key" {
  crypto_key_id = google_kms_crypto_key.primary_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:service-${data.google_project.current.number}@gcp-sa-cloud-sql.iam.gserviceaccount.com",
  ]
}

# Cloud SQL service account permissions for DR region
resource "google_kms_crypto_key_iam_binding" "dr_cloudsql_crypto_key" {
  crypto_key_id = google_kms_crypto_key.dr_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:service-${data.google_project.current.number}@gcp-sa-cloud-sql.iam.gserviceaccount.com",
  ]
}