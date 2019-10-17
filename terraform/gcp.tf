# This file contains all the interactions with Google Cloud
provider "google" {
  region  = var.region
  project = var.project
}

provider "google-beta" {
  region  = var.region
  project = var.project
}

# Generate a random id for the project - GCP projects must have globally
# unique names
resource "random_id" "project_random" {
  prefix      = "tzmon"
  byte_length = "8"
}

# Create the project if one isn't specified
resource "google_project" "tezos_monitor" {
  count           = var.project != "" ? 0 : 1
  name            = random_id.project_random.hex
  project_id      = random_id.project_random.hex
  org_id          = var.org_id
  billing_account = var.billing_account
}

# Or use an existing project, if defined
data "google_project" "tezos_monitor" {
  count      = var.project != "" ? 1 : 0
  project_id = var.project
}

# Obtain the project_id from either the newly created project resource or
# existing data project resource One will be populated and the other will be
# null
locals {
  tezos_monitor_project_id = element( concat(
      data.google_project.tezos_monitor.*.project_id,
      google_project.tezos_monitor.*.project_id,
    ),
    0,
  )
}

# Create the tezos_monitor service account
resource "google_service_account" "tezos-monitor-server" {
  account_id   = "tezos-monitor-server"
  display_name = "tezos_monitor Server"
  project      = local.tezos_monitor_project_id
}

# Create a service account key
resource "google_service_account_key" "tezos_monitor" {
  service_account_id = google_service_account.tezos-monitor-server.name
}

# Add the service account to the project
resource "google_project_iam_member" "service-account" {
  count   = length(var.service_account_iam_roles)
  project = local.tezos_monitor_project_id
  role    = element(var.service_account_iam_roles, count.index)
  member  = "serviceAccount:${google_service_account.tezos-monitor-server.email}"
}

# Enable required services on the project
resource "google_project_service" "service" {
  count   = length(var.project_services)
  project = local.tezos_monitor_project_id
  service = element(var.project_services, count.index)

  # Do not disable the service on destroy. On destroy, we are going to
  # destroy the project, but we need the APIs available to destroy the
  # underlying resources.
  disable_on_destroy = false
}

# Create an external NAT IP
resource "google_compute_address" "tezos-monitor-nat" {
  count   = 1
  name    = "tezos-monitor-nat-external-${count.index}"
  project = local.tezos_monitor_project_id
  region  = var.region

  depends_on = [google_project_service.service]
}

# Create a network for GKE
resource "google_compute_network" "tezos-monitor-network" {
  name                    = "tezos-monitor-network"
  project                 = local.tezos_monitor_project_id
  auto_create_subnetworks = false

  depends_on = [google_project_service.service]
}

# Create subnets
resource "google_compute_subnetwork" "tezos-monitor-subnetwork" {
  name          = "tezos-monitor-subnetwork"
  project       = local.tezos_monitor_project_id
  network       = google_compute_network.tezos-monitor-network.self_link
  region        = var.region
  ip_cidr_range = var.kubernetes_network_ipv4_cidr

  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "tezos-monitor-pods"
    ip_cidr_range = var.kubernetes_pods_ipv4_cidr
  }

  secondary_ip_range {
    range_name    = "tezos-monitor-svcs"
    ip_cidr_range = var.kubernetes_services_ipv4_cidr
  }
}

# Create a NAT router so the nodes can reach DockerHub, etc
resource "google_compute_router" "tezos-monitor-router" {
  name    = "tezos-monitor-router"
  project = local.tezos_monitor_project_id
  region  = var.region
  network = google_compute_network.tezos-monitor-network.self_link

  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "tezos-monitor-nat" {
  name    = "tezos-monitor-nat-1"
  project = local.tezos_monitor_project_id
  router  = google_compute_router.tezos-monitor-router.name
  region  = var.region

  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips                = google_compute_address.tezos-monitor-nat.*.self_link

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.tezos-monitor-subnetwork.self_link
    source_ip_ranges_to_nat = ["PRIMARY_IP_RANGE", "LIST_OF_SECONDARY_IP_RANGES"]

    secondary_ip_range_names = [
      google_compute_subnetwork.tezos-monitor-subnetwork.secondary_ip_range[0].range_name,
      google_compute_subnetwork.tezos-monitor-subnetwork.secondary_ip_range[1].range_name,
    ]
  }
}

# Get latest cluster version
data "google_container_engine_versions" "versions" {
  project  = local.tezos_monitor_project_id
  location = var.region
}

# Create the GKE cluster
resource "google_container_cluster" "tezos_monitor" {
  provider = google-beta

  name     = "tezos-monitor"
  project  = local.tezos_monitor_project_id
  location = var.region
  node_locations = var.node_locations

  network    = google_compute_network.tezos-monitor-network.self_link
  subnetwork = google_compute_subnetwork.tezos-monitor-subnetwork.self_link

  initial_node_count = var.kubernetes_nodes_per_zone

  min_master_version = data.google_container_engine_versions.versions.latest_master_version

  logging_service    = var.kubernetes_logging_service
  monitoring_service = var.kubernetes_monitoring_service

  # Disable legacy ACLs. The default is false, but explicitly marking it false
  # here as well.
  enable_legacy_abac = false


  # Configure various addons
  addons_config {
    # Disable the Kubernetes dashboard, which is often an attack vector. The
    # cluster can still be managed via the GKE UI.
    kubernetes_dashboard {
      disabled = true
    }

    # disable all network policy, for monitoring node
    network_policy_config {
      disabled = true
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  # Disable basic authentication and cert-based authentication.
  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # disable network policy
  network_policy {
    enabled = false
  }

  # Set the maintenance window.
  maintenance_policy {
    daily_maintenance_window {
      start_time = var.kubernetes_daily_maintenance_window
    }
  }

  # Allocate IPs in our subnetwork
  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.tezos-monitor-subnetwork.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.tezos-monitor-subnetwork.secondary_ip_range[1].range_name
  }

  # Specify the list of CIDRs which can access the master's API
  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.kubernetes_master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  # Configure the cluster to be private (not have public facing IPs)
  private_cluster_config {
    # This field is misleading. This prevents access to the master API from
    # any external IP. While that might represent the most secure
    # configuration, it is not ideal for most setups. As such, we disable the
    # private endpoint (allow the public endpoint) and restrict which CIDRs
    # can talk to that endpoint.
    enable_private_endpoint = false

    enable_private_nodes   = true
    master_ipv4_cidr_block = var.kubernetes_masters_ipv4_cidr
  }

  depends_on = [
    google_project_service.service,
    google_project_iam_member.service-account,
    google_compute_router_nat.tezos-monitor-nat,
  ]
  remove_default_node_pool = true
  vertical_pod_autoscaling {
    enabled = true
  }
}


resource "google_container_node_pool" "tezos_monitor_node_pool" {
  provider = google-beta
  project = local.tezos_monitor_project_id
  name       = "tzmonitor-pool"
  location   = var.region

  version       = data.google_container_engine_versions.versions.latest_node_version
  cluster    = "${google_container_cluster.tezos_monitor.name}"
  node_count = 1

  management {
     auto_repair = "true"
     auto_upgrade = "true"
  }

  node_config {
    machine_type    = var.kubernetes_instance_type_steady
    service_account = google_service_account.tezos-monitor-server.email

    # Set metadata on the VM to supply more entropy
    metadata = {
      google-compute-enable-virtio-rng = "true"
      disable-legacy-endpoints         = "true"
    }

    labels = {
      service = "tezos_monitor"
    }


    # Protect node metadata
    workload_metadata_config {
      node_metadata = "SECURE"
    }
    preemptible  = true
    image_type = "COS"
    disk_type = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

resource "random_id" "rnd" {
  byte_length = 4
}

resource "google_storage_bucket" "website" {
  name     = "tezos-snapshot-generator-website-static-bucket-${random_id.rnd.hex}"
  project = local.tezos_monitor_project_id

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
  force_destroy = true
}

resource "google_service_account" "website_pusher" {
  account_id   = "website-pusher"
  display_name = "Tezos Website Pusher"
  project = local.tezos_monitor_project_id
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = "${google_storage_bucket.website.name}"
  role        = "roles/storage.objectAdmin"
  member      = "serviceAccount:${google_service_account.website_pusher.email}"
}

resource "google_storage_bucket_iam_member" "make_public" {
  bucket = "${google_storage_bucket.website.name}"
  role        = "roles/storage.objectViewer"
  member      = "allUsers"
}

resource "google_service_account_key" "website_builder_key" {
  service_account_id = google_service_account.website_pusher.name
}
