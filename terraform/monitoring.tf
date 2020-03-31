# Create the prometheus service account
resource "google_service_account" "prometheus-service-account" {
  account_id   = "prometheus-service-account"
  display_name = "prometheus-service-account"
  project      = local.tezos_monitor_project_id
}

resource "google_project_iam_member" "admin-account-iam" {
  project      = local.tezos_monitor_project_id
  role               = "roles/monitoring.metricWriter"
  member             = "serviceAccount:${google_service_account.prometheus-service-account.email}"
}
